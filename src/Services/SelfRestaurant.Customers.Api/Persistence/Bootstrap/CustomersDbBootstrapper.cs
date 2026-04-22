using System.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using SelfRestaurant.Customers.Api.Persistence.Entities;

namespace SelfRestaurant.Customers.Api.Persistence;

public static class CustomersDbBootstrapper
{
    public static async Task EnsureReadyAsync(
        IServiceProvider services,
        ILogger logger,
        CancellationToken cancellationToken = default)
    {
        using var scope = services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<CustomersDbContext>();

        await WaitForDatabaseAsync(db, logger, cancellationToken);
        await EnsureInboxTableAsync(db, cancellationToken);
        await EnsureReadyNotificationsTableAsync(db, cancellationToken);
    }

    private static async Task WaitForDatabaseAsync(CustomersDbContext db, ILogger logger, CancellationToken cancellationToken)
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

    private static async Task EnsureInboxTableAsync(CustomersDbContext db, CancellationToken cancellationToken)
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
                                   Status VARCHAR(30) NOT NULL CONSTRAINT DF_CustomersInboxEvents_Status DEFAULT ('PROCESSED'),
                                   RetryCount INT NOT NULL CONSTRAINT DF_CustomersInboxEvents_RetryCount DEFAULT (0),
                                   ReceivedAtUtc DATETIME2 NOT NULL CONSTRAINT DF_CustomersInboxEvents_ReceivedAtUtc DEFAULT (SYSUTCDATETIME()),
                                   NextRetryAtUtc DATETIME2 NULL,
                                   ProcessedAtUtc DATETIME2 NULL,
                                   Error NVARCHAR(MAX) NULL
                               );
                               CREATE UNIQUE INDEX UX_InboxEvents_Source_SourceEventId ON dbo.InboxEvents(Source, SourceEventId);
                               CREATE INDEX IX_InboxEvents_ReceivedAtUtc ON dbo.InboxEvents(ReceivedAtUtc);
                           END
                           """;
        await db.Database.ExecuteSqlRawAsync(sql, cancellationToken);
    }

    private static async Task EnsureReadyNotificationsTableAsync(CustomersDbContext db, CancellationToken cancellationToken)
    {
        const string sql = """
                           IF OBJECT_ID(N'dbo.ReadyDishNotifications', N'U') IS NULL
                           BEGIN
                               CREATE TABLE dbo.ReadyDishNotifications
                               (
                                   ReadyDishNotificationId BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
                                   OrderId INT NOT NULL,
                                   OrderItemId INT NULL,
                                   DishId INT NULL,
                                   DishName NVARCHAR(200) NULL,
                                   CustomerId INT NULL,
                                   TableId INT NULL,
                                   EventName VARCHAR(100) NOT NULL CONSTRAINT DF_ReadyDishNotifications_EventName DEFAULT ('order.status-ready.v1'),
                                   Message NVARCHAR(500) NOT NULL,
                                   Status VARCHAR(30) NOT NULL CONSTRAINT DF_ReadyDishNotifications_Status DEFAULT ('OPEN'),
                                   CreatedAtUtc DATETIME2 NOT NULL CONSTRAINT DF_ReadyDishNotifications_CreatedAtUtc DEFAULT (SYSUTCDATETIME()),
                                   ResolvedAtUtc DATETIME2 NULL
                               );
                               CREATE INDEX IX_ReadyDishNotifications_Order_Item_Event ON dbo.ReadyDishNotifications(OrderId, OrderItemId, EventName);
                           END

                           IF COL_LENGTH('dbo.ReadyDishNotifications', 'OrderItemId') IS NULL
                           BEGIN
                               ALTER TABLE dbo.ReadyDishNotifications ADD OrderItemId INT NULL;
                           END

                           IF COL_LENGTH('dbo.ReadyDishNotifications', 'DishId') IS NULL
                           BEGIN
                               ALTER TABLE dbo.ReadyDishNotifications ADD DishId INT NULL;
                           END

                           IF COL_LENGTH('dbo.ReadyDishNotifications', 'DishName') IS NULL
                           BEGIN
                               ALTER TABLE dbo.ReadyDishNotifications ADD DishName NVARCHAR(200) NULL;
                           END

                           IF EXISTS (
                               SELECT 1
                               FROM sys.indexes
                               WHERE object_id = OBJECT_ID(N'dbo.ReadyDishNotifications')
                                 AND name = N'IX_ReadyDishNotifications_Order_Event'
                           )
                           BEGIN
                               DROP INDEX IX_ReadyDishNotifications_Order_Event ON dbo.ReadyDishNotifications;
                           END

                           IF NOT EXISTS (
                               SELECT 1
                               FROM sys.indexes
                               WHERE object_id = OBJECT_ID(N'dbo.ReadyDishNotifications')
                                 AND name = N'IX_ReadyDishNotifications_Order_Item_Event'
                           )
                           BEGIN
                               CREATE INDEX IX_ReadyDishNotifications_Order_Item_Event
                                   ON dbo.ReadyDishNotifications(OrderId, OrderItemId, EventName);
                           END
                           """;
        await db.Database.ExecuteSqlRawAsync(sql, cancellationToken);
    }
}
