using System.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using SelfRestaurant.Orders.Api.Persistence.Entities;

namespace SelfRestaurant.Orders.Api.Persistence;

public static class OrdersDbBootstrapper
{
    public static async Task EnsureReadyAsync(
        IServiceProvider services,
        ILogger logger,
        CancellationToken cancellationToken = default)
    {
        using var scope = services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<OrdersDbContext>();

        await WaitForDatabaseAsync(db, logger, cancellationToken);
        await EnsureOutboxTableAsync(db, cancellationToken);
        await EnsureInboxTableAsync(db, cancellationToken);
        await SeedReferenceDataAsync(db, logger, cancellationToken);
    }

    private static async Task WaitForDatabaseAsync(OrdersDbContext db, ILogger logger, CancellationToken cancellationToken)
    {
        var delay = TimeSpan.FromSeconds(1);

        for (var attempt = 1; attempt <= 60; attempt++)
        {
            try
            {
                await db.Database.OpenConnectionAsync(cancellationToken);
                try
                {
                    await using var command = db.Database.GetDbConnection().CreateCommand();
                    command.CommandText = "SELECT 1";
                    command.CommandType = CommandType.Text;
                    _ = await command.ExecuteScalarAsync(cancellationToken);
                }
                finally
                {
                    try
                    {
                        await db.Database.CloseConnectionAsync();
                    }
                    catch
                    {
                        // ignored
                    }
                }

                return;
            }
            catch (Exception ex) when (attempt < 60)
            {
                logger.LogWarning(ex, "Database not ready (attempt {Attempt}/60). Waiting {Delay}...", attempt, delay);
                await Task.Delay(delay, cancellationToken);
                delay = TimeSpan.FromSeconds(Math.Min(delay.TotalSeconds * 1.5, 10));
            }
        }
    }

    private static async Task SeedReferenceDataAsync(OrdersDbContext db, ILogger logger, CancellationToken cancellationToken)
    {
        if (!await TableExistsAsync(db, "OrderStatus", cancellationToken) || !await TableExistsAsync(db, "TableStatus", cancellationToken))
        {
            logger.LogWarning("Missing expected tables; skipping seed.");
            return;
        }

        var changed = false;

        if (!await db.OrderStatus.AnyAsync(cancellationToken))
        {
            db.OrderStatus.AddRange(
                new OrderStatus { StatusCode = "PENDING", StatusName = "Chờ xác nhận" },
                new OrderStatus { StatusCode = "CONFIRMED", StatusName = "Đã xác nhận" },
                new OrderStatus { StatusCode = "PREPARING", StatusName = "Đang chuẩn bị" },
                new OrderStatus { StatusCode = "READY", StatusName = "Sẵn sàng" },
                new OrderStatus { StatusCode = "SERVING", StatusName = "Đang phục vụ" },
                new OrderStatus { StatusCode = "COMPLETED", StatusName = "Hoàn tất" },
                new OrderStatus { StatusCode = "CANCELLED", StatusName = "Đã huỷ" });
            changed = true;
        }

        if (!await db.TableStatus.AnyAsync(cancellationToken))
        {
            db.TableStatus.AddRange(
                new TableStatus { StatusCode = "AVAILABLE", StatusName = "Trống" },
                new TableStatus { StatusCode = "OCCUPIED", StatusName = "Đang dùng" },
                new TableStatus { StatusCode = "RESERVED", StatusName = "Đặt trước" },
                new TableStatus { StatusCode = "INACTIVE", StatusName = "Không hoạt động" });
            changed = true;
        }

        if (changed)
        {
            await db.SaveChangesAsync(cancellationToken);
        }
    }

    private static async Task<bool> TableExistsAsync(OrdersDbContext db, string tableName, CancellationToken cancellationToken)
    {
        await db.Database.OpenConnectionAsync(cancellationToken);
        try
        {
            await using var command = db.Database.GetDbConnection().CreateCommand();
            command.CommandText = """
                                 SELECT 1
                                 FROM
                                 (
                                     SELECT name
                                     FROM sys.tables
                                     WHERE schema_id = SCHEMA_ID('dbo')

                                     UNION ALL

                                     SELECT name
                                     FROM sys.views
                                     WHERE schema_id = SCHEMA_ID('dbo')

                                     UNION ALL

                                     SELECT name
                                     FROM sys.synonyms
                                     WHERE schema_id = SCHEMA_ID('dbo')
                                 ) AS objects
                                 WHERE name = @table
                                 """;
            var parameter = command.CreateParameter();
            parameter.ParameterName = "@table";
            parameter.Value = tableName;
            command.Parameters.Add(parameter);

            var result = await command.ExecuteScalarAsync(cancellationToken);
            return result is not null;
        }
        finally
        {
            await db.Database.CloseConnectionAsync();
        }
    }

    private static async Task EnsureOutboxTableAsync(OrdersDbContext db, CancellationToken cancellationToken)
    {
        const string sql = """
                           IF OBJECT_ID(N'dbo.OutboxEvents', N'U') IS NULL
                           BEGIN
                               CREATE TABLE dbo.OutboxEvents
                               (
                                   OutboxEventId BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
                                   EventName VARCHAR(200) NOT NULL,
                                   OccurredAtUtc DATETIME2 NOT NULL,
                                   Source VARCHAR(100) NOT NULL,
                                   CorrelationId VARCHAR(100) NULL,
                                   PayloadJson NVARCHAR(MAX) NOT NULL,
                                   Status VARCHAR(30) NOT NULL CONSTRAINT DF_OutboxEvents_Status DEFAULT ('PENDING'),
                                   CreatedAtUtc DATETIME2 NOT NULL CONSTRAINT DF_OutboxEvents_CreatedAtUtc DEFAULT (SYSUTCDATETIME()),
                                   ProcessedAtUtc DATETIME2 NULL,
                                   Error NVARCHAR(MAX) NULL
                               );
                               CREATE INDEX IX_OutboxEvents_Status ON dbo.OutboxEvents(Status);
                               CREATE INDEX IX_OutboxEvents_CreatedAtUtc ON dbo.OutboxEvents(CreatedAtUtc);
                           END

                           IF NOT EXISTS
                           (
                               SELECT 1
                               FROM sys.indexes
                               WHERE object_id = OBJECT_ID(N'dbo.OutboxEvents')
                                 AND name = N'IX_OutboxEvents_Status_EventName_CreatedAtUtc'
                           )
                           BEGIN
                               CREATE INDEX IX_OutboxEvents_Status_EventName_CreatedAtUtc
                               ON dbo.OutboxEvents(Status, EventName, CreatedAtUtc);
                           END

                           UPDATE dbo.OutboxEvents
                           SET Status = 'PROCESSED',
                               ProcessedAtUtc = ISNULL(ProcessedAtUtc, SYSUTCDATETIME()),
                               Error = COALESCE(NULLIF(Error, ''), 'AUTO:untracked-event')
                           WHERE Status = 'PENDING'
                             AND EventName <> 'order.status-ready.v1';
                           """;

        await db.Database.ExecuteSqlRawAsync(sql, cancellationToken);
    }

    private static async Task EnsureInboxTableAsync(OrdersDbContext db, CancellationToken cancellationToken)
    {
        const string sql = """
                           IF OBJECT_ID(N'dbo.InboxEvents', N'U') IS NULL
                           BEGIN
                               CREATE TABLE dbo.InboxEvents
                               (
                                   InboxEventId BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
                                   Source VARCHAR(100) NOT NULL,
                                   SourceEventId BIGINT NOT NULL,
                                   EventName VARCHAR(200) NOT NULL,
                                   CorrelationId VARCHAR(100) NULL,
                                   PayloadJson NVARCHAR(MAX) NOT NULL,
                                   Status VARCHAR(30) NOT NULL CONSTRAINT DF_InboxEvents_Status DEFAULT ('PROCESSED'),
                                   RetryCount INT NOT NULL CONSTRAINT DF_InboxEvents_RetryCount DEFAULT (0),
                                   ReceivedAtUtc DATETIME2 NOT NULL CONSTRAINT DF_InboxEvents_ReceivedAtUtc DEFAULT (SYSUTCDATETIME()),
                                   NextRetryAtUtc DATETIME2 NULL,
                                   ProcessedAtUtc DATETIME2 NULL,
                                   Error NVARCHAR(MAX) NULL
                               );
                               CREATE UNIQUE INDEX UX_InboxEvents_Source_SourceEventId ON dbo.InboxEvents(Source, SourceEventId);
                               CREATE INDEX IX_InboxEvents_ReceivedAtUtc ON dbo.InboxEvents(ReceivedAtUtc);
                           END

                           IF COL_LENGTH('dbo.InboxEvents', 'RetryCount') IS NULL
                           BEGIN
                               ALTER TABLE dbo.InboxEvents ADD RetryCount INT NOT NULL CONSTRAINT DF_InboxEvents_RetryCount_Migrate DEFAULT (0);
                           END

                           IF COL_LENGTH('dbo.InboxEvents', 'NextRetryAtUtc') IS NULL
                           BEGIN
                               ALTER TABLE dbo.InboxEvents ADD NextRetryAtUtc DATETIME2 NULL;
                           END
                           """;

        await db.Database.ExecuteSqlRawAsync(sql, cancellationToken);
    }
}
