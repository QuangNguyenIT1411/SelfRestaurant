using System.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace SelfRestaurant.Billing.Api.Persistence;

public static class BillingDbBootstrapper
{
    public static async Task EnsureReadyAsync(
        IServiceProvider services,
        ILogger logger,
        CancellationToken cancellationToken = default)
    {
        using var scope = services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<BillingDbContext>();

        await WaitForDatabaseAsync(db, logger, cancellationToken);
        await EnsureOutboxTableAsync(db, cancellationToken);
        await EnsureBillSnapshotColumnsAsync(db, cancellationToken);
        await EnsureBillsDetachedFromLegacyOrderFkAsync(db, cancellationToken);
        await EnsureBillsDetachedFromLegacyCustomerFkAsync(db, cancellationToken);
        await EnsureOrderContextSnapshotTableAsync(db, cancellationToken);
        await SeedReferenceDataAsync(db, logger, cancellationToken);
    }

    private static async Task WaitForDatabaseAsync(BillingDbContext db, ILogger logger, CancellationToken cancellationToken)
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

    private static Task SeedReferenceDataAsync(BillingDbContext db, ILogger logger, CancellationToken cancellationToken)
    {
        logger.LogInformation("Billing reference seed skipped; service no longer owns OrderStatus/TableStatus.");
        return Task.CompletedTask;
    }

    private static async Task EnsureOutboxTableAsync(BillingDbContext db, CancellationToken cancellationToken)
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
                           """;

        await db.Database.ExecuteSqlRawAsync(sql, cancellationToken);
    }

    private static async Task EnsureBillSnapshotColumnsAsync(BillingDbContext db, CancellationToken cancellationToken)
    {
        const string sql = """
                           DECLARE @targetObject nvarchar(512) = N'dbo.Bills';
                           DECLARE @baseObject nvarchar(512) =
                               (SELECT TOP 1 base_object_name
                                FROM sys.synonyms
                                WHERE schema_id = SCHEMA_ID(N'dbo')
                                  AND name = N'Bills');

                           IF @baseObject IS NOT NULL
                               SET @targetObject = @baseObject;

                           IF COL_LENGTH(@targetObject, 'OrderCodeSnapshot') IS NULL
                               EXEC(N'ALTER TABLE ' + @targetObject + N' ADD OrderCodeSnapshot NVARCHAR(50) NULL;');

                           IF COL_LENGTH(@targetObject, 'TableIdSnapshot') IS NULL
                               EXEC(N'ALTER TABLE ' + @targetObject + N' ADD TableIdSnapshot INT NULL;');

                           IF COL_LENGTH(@targetObject, 'TableNameSnapshot') IS NULL
                               EXEC(N'ALTER TABLE ' + @targetObject + N' ADD TableNameSnapshot NVARCHAR(200) NULL;');

                           IF COL_LENGTH(@targetObject, 'BranchIdSnapshot') IS NULL
                               EXEC(N'ALTER TABLE ' + @targetObject + N' ADD BranchIdSnapshot INT NULL;');

                           IF COL_LENGTH(@targetObject, 'BranchNameSnapshot') IS NULL
                               EXEC(N'ALTER TABLE ' + @targetObject + N' ADD BranchNameSnapshot NVARCHAR(200) NULL;');
                           """;

        await db.Database.ExecuteSqlRawAsync(sql, cancellationToken);
    }

    private static async Task EnsureBillsDetachedFromLegacyOrderFkAsync(BillingDbContext db, CancellationToken cancellationToken)
    {
        const string sql = """
                           DECLARE @targetObject nvarchar(512) = N'dbo.Bills';
                           DECLARE @baseObject nvarchar(512) =
                               (SELECT TOP 1 base_object_name
                                FROM sys.synonyms
                                WHERE schema_id = SCHEMA_ID(N'dbo')
                                  AND name = N'Bills');

                           IF @baseObject IS NOT NULL
                               SET @targetObject = @baseObject;

                           DECLARE @targetDb sysname = ISNULL(PARSENAME(@targetObject, 3), DB_NAME());
                           DECLARE @targetSchema sysname = ISNULL(PARSENAME(@targetObject, 2), N'dbo');
                           DECLARE @targetTable sysname = PARSENAME(@targetObject, 1);
                           DECLARE @dynamicSql nvarchar(max) = N'
                               IF EXISTS (
                                   SELECT 1
                                   FROM ' + QUOTENAME(@targetDb) + N'.sys.foreign_keys fk
                                   INNER JOIN ' + QUOTENAME(@targetDb) + N'.sys.tables t ON fk.parent_object_id = t.object_id
                                   INNER JOIN ' + QUOTENAME(@targetDb) + N'.sys.schemas s ON t.schema_id = s.schema_id
                                   WHERE fk.name = N''FK_Bills_Orders''
                                     AND s.name = N''' + REPLACE(@targetSchema, '''', '''''') + N'''
                                     AND t.name = N''' + REPLACE(@targetTable, '''', '''''') + N'''
                               )
                               BEGIN
                                   ALTER TABLE ' + QUOTENAME(@targetDb) + N'.' + QUOTENAME(@targetSchema) + N'.' + QUOTENAME(@targetTable) + N' DROP CONSTRAINT [FK_Bills_Orders];
                               END';

                           EXEC sp_executesql @dynamicSql;
                           """;

        await db.Database.ExecuteSqlRawAsync(sql, cancellationToken);
    }

    private static async Task EnsureBillsDetachedFromLegacyCustomerFkAsync(BillingDbContext db, CancellationToken cancellationToken)
    {
        const string sql = """
                           DECLARE @targetObject nvarchar(512) = N'dbo.Bills';
                           DECLARE @baseObject nvarchar(512) =
                               (SELECT TOP 1 base_object_name
                                FROM sys.synonyms
                                WHERE schema_id = SCHEMA_ID(N'dbo')
                                  AND name = N'Bills');

                           IF @baseObject IS NOT NULL
                               SET @targetObject = @baseObject;

                           DECLARE @targetDb sysname = ISNULL(PARSENAME(@targetObject, 3), DB_NAME());
                           DECLARE @targetSchema sysname = ISNULL(PARSENAME(@targetObject, 2), N'dbo');
                           DECLARE @targetTable sysname = PARSENAME(@targetObject, 1);
                           DECLARE @dynamicSql nvarchar(max) = N'
                               IF EXISTS (
                                   SELECT 1
                                   FROM ' + QUOTENAME(@targetDb) + N'.sys.foreign_keys fk
                                   INNER JOIN ' + QUOTENAME(@targetDb) + N'.sys.tables t ON fk.parent_object_id = t.object_id
                                   INNER JOIN ' + QUOTENAME(@targetDb) + N'.sys.schemas s ON t.schema_id = s.schema_id
                                   WHERE fk.name = N''FK_Bills_Customers''
                                     AND s.name = N''' + REPLACE(@targetSchema, '''', '''''') + N'''
                                     AND t.name = N''' + REPLACE(@targetTable, '''', '''''') + N'''
                               )
                               BEGIN
                                   ALTER TABLE ' + QUOTENAME(@targetDb) + N'.' + QUOTENAME(@targetSchema) + N'.' + QUOTENAME(@targetTable) + N' DROP CONSTRAINT [FK_Bills_Customers];
                               END';

                           EXEC sp_executesql @dynamicSql;
                           """;

        await db.Database.ExecuteSqlRawAsync(sql, cancellationToken);
    }

    private static async Task EnsureOrderContextSnapshotTableAsync(BillingDbContext db, CancellationToken cancellationToken)
    {
        const string sql = """
                           IF OBJECT_ID(N'dbo.OrderContextSnapshots', N'U') IS NULL
                           BEGIN
                               CREATE TABLE dbo.OrderContextSnapshots
                               (
                                   OrderId INT NOT NULL PRIMARY KEY,
                                   OrderCode NVARCHAR(50) NULL,
                                   TableId INT NULL,
                                   TableName NVARCHAR(200) NULL,
                                   BranchId INT NULL,
                                   BranchName NVARCHAR(200) NULL,
                                   RefreshedAtUtc DATETIME2 NOT NULL CONSTRAINT DF_OrderContextSnapshots_RefreshedAtUtc DEFAULT SYSUTCDATETIME()
                               );
                               CREATE INDEX IX_OrderContextSnapshots_BranchId ON dbo.OrderContextSnapshots(BranchId);
                               CREATE INDEX IX_OrderContextSnapshots_RefreshedAtUtc ON dbo.OrderContextSnapshots(RefreshedAtUtc);
                           END
                           """;

        await db.Database.ExecuteSqlRawAsync(sql, cancellationToken);
    }
}
