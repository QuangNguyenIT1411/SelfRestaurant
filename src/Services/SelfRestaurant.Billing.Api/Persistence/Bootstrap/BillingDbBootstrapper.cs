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
        await EnsureBillIdempotencyColumnsAsync(db, cancellationToken);
        await EnsureBusinessAuditTableAsync(db, cancellationToken);
        await EnsureBillsDetachedFromLegacyOrderFkAsync(db, cancellationToken);
        await EnsureBillsDetachedFromLegacyCustomerFkAsync(db, cancellationToken);
        await EnsureOrderContextSnapshotTableAsync(db, cancellationToken);
        await EnsureCheckoutCommandTableAsync(db, cancellationToken);
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

    private static async Task EnsureBusinessAuditTableAsync(BillingDbContext db, CancellationToken cancellationToken)
    {
        const string createSql = """
                                 IF OBJECT_ID(N'dbo.BusinessAuditLogs', N'U') IS NULL
                                 BEGIN
                                     CREATE TABLE dbo.BusinessAuditLogs
                                     (
                                         BusinessAuditLogId BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
                                         CreatedAtUtc DATETIME2 NOT NULL CONSTRAINT DF_BillingBusinessAuditLogs_CreatedAtUtc DEFAULT (SYSUTCDATETIME()),
                                         ActionType VARCHAR(100) NOT NULL,
                                         EntityType VARCHAR(50) NOT NULL,
                                         EntityId NVARCHAR(100) NOT NULL,
                                         ActorType VARCHAR(30) NULL,
                                         ActorId INT NULL,
                                         ActorCode NVARCHAR(100) NULL,
                                         ActorName NVARCHAR(200) NULL,
                                         ActorRoleCode VARCHAR(50) NULL,
                                         TableId INT NULL,
                                         OrderId INT NULL,
                                         OrderItemId INT NULL,
                                         DishId INT NULL,
                                         BillId INT NULL,
                                         DiningSessionCode VARCHAR(64) NULL,
                                         CorrelationId VARCHAR(100) NULL,
                                         IdempotencyKey VARCHAR(100) NULL,
                                         Notes NVARCHAR(500) NULL,
                                         BeforeState NVARCHAR(MAX) NULL,
                                         AfterState NVARCHAR(MAX) NULL
                                     );
                                 END
                                 """;

        const string indexSql = """
                                IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.BusinessAuditLogs') AND name = N'IX_BusinessAuditLogs_CreatedAtUtc')
                                    CREATE INDEX IX_BusinessAuditLogs_CreatedAtUtc ON dbo.BusinessAuditLogs(CreatedAtUtc);

                                IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.BusinessAuditLogs') AND name = N'IX_BusinessAuditLogs_Entity')
                                    CREATE INDEX IX_BusinessAuditLogs_Entity ON dbo.BusinessAuditLogs(EntityType, EntityId);

                                IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.BusinessAuditLogs') AND name = N'IX_BusinessAuditLogs_OrderId')
                                    CREATE INDEX IX_BusinessAuditLogs_OrderId ON dbo.BusinessAuditLogs(OrderId);

                                IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.BusinessAuditLogs') AND name = N'IX_BusinessAuditLogs_BillId')
                                    CREATE INDEX IX_BusinessAuditLogs_BillId ON dbo.BusinessAuditLogs(BillId);
                                """;

        await db.Database.ExecuteSqlRawAsync(createSql, cancellationToken);
        await db.Database.ExecuteSqlRawAsync(indexSql, cancellationToken);
    }

    private static async Task EnsureOutboxTableAsync(BillingDbContext db, CancellationToken cancellationToken)
    {
        await db.Database.ExecuteSqlRawAsync("""
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
            END
            """, cancellationToken);

        await db.Database.ExecuteSqlRawAsync("""
            IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.OutboxEvents') AND name = N'IX_OutboxEvents_Status')
                CREATE INDEX IX_OutboxEvents_Status ON dbo.OutboxEvents(Status);

            IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.OutboxEvents') AND name = N'IX_OutboxEvents_CreatedAtUtc')
                CREATE INDEX IX_OutboxEvents_CreatedAtUtc ON dbo.OutboxEvents(CreatedAtUtc);
            """, cancellationToken);
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

    private static async Task EnsureBillIdempotencyColumnsAsync(BillingDbContext db, CancellationToken cancellationToken)
    {
        // Split column adds from index creation so an older schema can recover even if a previous
        // startup stopped after ALTER TABLE but before the dependent index statements ran.
        const string addColumnsSql = """
                                     DECLARE @targetObject nvarchar(512) = N'dbo.Bills';
                                     DECLARE @baseObject nvarchar(512) =
                                         (SELECT TOP 1 base_object_name
                                          FROM sys.synonyms
                                          WHERE schema_id = SCHEMA_ID(N'dbo')
                                            AND name = N'Bills');

                                     IF @baseObject IS NOT NULL
                                         SET @targetObject = @baseObject;

                                     IF COL_LENGTH(@targetObject, 'DiningSessionCode') IS NULL
                                         EXEC(N'ALTER TABLE ' + @targetObject + N' ADD DiningSessionCode VARCHAR(64) NULL;');

                                     IF COL_LENGTH(@targetObject, 'CheckoutIdempotencyKey') IS NULL
                                         EXEC(N'ALTER TABLE ' + @targetObject + N' ADD CheckoutIdempotencyKey VARCHAR(100) NULL;');
                                     """;

        const string addIndexesSql = """
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
                                     DECLARE @indexSql nvarchar(max) = N'
                                         IF NOT EXISTS (
                                             SELECT 1
                                             FROM ' + QUOTENAME(@targetDb) + N'.sys.indexes i
                                             INNER JOIN ' + QUOTENAME(@targetDb) + N'.sys.tables t ON i.object_id = t.object_id
                                             INNER JOIN ' + QUOTENAME(@targetDb) + N'.sys.schemas s ON t.schema_id = s.schema_id
                                             WHERE i.name = N''UX_Bills_CheckoutIdempotencyKey''
                                               AND s.name = N''' + REPLACE(@targetSchema, '''', '''''') + N'''
                                               AND t.name = N''' + REPLACE(@targetTable, '''', '''''') + N'''
                                         )
                                         BEGIN
                                             CREATE UNIQUE INDEX UX_Bills_CheckoutIdempotencyKey
                                             ON ' + QUOTENAME(@targetDb) + N'.' + QUOTENAME(@targetSchema) + N'.' + QUOTENAME(@targetTable) + N'(CheckoutIdempotencyKey)
                                             WHERE CheckoutIdempotencyKey IS NOT NULL;
                                         END';

                                     EXEC sp_executesql @indexSql;

                                     DECLARE @activeOrderIndexSql nvarchar(max) = N'
                                         IF NOT EXISTS (
                                             SELECT 1
                                             FROM ' + QUOTENAME(@targetDb) + N'.sys.indexes i
                                             INNER JOIN ' + QUOTENAME(@targetDb) + N'.sys.tables t ON i.object_id = t.object_id
                                             INNER JOIN ' + QUOTENAME(@targetDb) + N'.sys.schemas s ON t.schema_id = s.schema_id
                                             WHERE i.name = N''UX_Bills_OrderID_Active''
                                               AND s.name = N''' + REPLACE(@targetSchema, '''', '''''') + N'''
                                               AND t.name = N''' + REPLACE(@targetTable, '''', '''''') + N'''
                                         )
                                         BEGIN
                                             CREATE UNIQUE INDEX UX_Bills_OrderID_Active
                                             ON ' + QUOTENAME(@targetDb) + N'.' + QUOTENAME(@targetSchema) + N'.' + QUOTENAME(@targetTable) + N'(OrderID)
                                             WHERE IsActive = 1;
                                         END';

                                     EXEC sp_executesql @activeOrderIndexSql;
                                     """;

        await db.Database.ExecuteSqlRawAsync(addColumnsSql, cancellationToken);
        await db.Database.ExecuteSqlRawAsync(addIndexesSql, cancellationToken);
    }

    private static async Task EnsureCheckoutCommandTableAsync(BillingDbContext db, CancellationToken cancellationToken)
    {
        await db.Database.ExecuteSqlRawAsync("""
            IF OBJECT_ID(N'dbo.CheckoutCommands', N'U') IS NULL
            BEGIN
                CREATE TABLE dbo.CheckoutCommands
                (
                    CheckoutCommandId BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
                    IdempotencyKey VARCHAR(100) NOT NULL,
                    OrderId INT NOT NULL,
                    DiningSessionCode VARCHAR(64) NULL,
                    BillId INT NULL,
                    BillCode NVARCHAR(50) NULL,
                    TotalAmount DECIMAL(18, 2) NULL,
                    ChangeAmount DECIMAL(18, 2) NULL,
                    PointsUsed INT NULL,
                    PointsEarned INT NULL,
                    CustomerPoints INT NULL,
                    PointsBefore INT NULL,
                    CustomerName NVARCHAR(200) NULL,
                    Status VARCHAR(20) NOT NULL CONSTRAINT DF_CheckoutCommands_Status DEFAULT ('PENDING'),
                    CreatedAtUtc DATETIME2 NOT NULL CONSTRAINT DF_CheckoutCommands_CreatedAtUtc DEFAULT (SYSUTCDATETIME()),
                    CompletedAtUtc DATETIME2 NULL,
                    Error NVARCHAR(MAX) NULL
                );
            END
            """, cancellationToken);

        await db.Database.ExecuteSqlRawAsync("""
            IF COL_LENGTH(N'dbo.CheckoutCommands', 'BillCode') IS NULL
                ALTER TABLE dbo.CheckoutCommands ADD BillCode NVARCHAR(50) NULL;
            IF COL_LENGTH(N'dbo.CheckoutCommands', 'TotalAmount') IS NULL
                ALTER TABLE dbo.CheckoutCommands ADD TotalAmount DECIMAL(18, 2) NULL;
            IF COL_LENGTH(N'dbo.CheckoutCommands', 'ChangeAmount') IS NULL
                ALTER TABLE dbo.CheckoutCommands ADD ChangeAmount DECIMAL(18, 2) NULL;
            IF COL_LENGTH(N'dbo.CheckoutCommands', 'PointsUsed') IS NULL
                ALTER TABLE dbo.CheckoutCommands ADD PointsUsed INT NULL;
            IF COL_LENGTH(N'dbo.CheckoutCommands', 'PointsEarned') IS NULL
                ALTER TABLE dbo.CheckoutCommands ADD PointsEarned INT NULL;
            IF COL_LENGTH(N'dbo.CheckoutCommands', 'CustomerPoints') IS NULL
                ALTER TABLE dbo.CheckoutCommands ADD CustomerPoints INT NULL;
            IF COL_LENGTH(N'dbo.CheckoutCommands', 'PointsBefore') IS NULL
                ALTER TABLE dbo.CheckoutCommands ADD PointsBefore INT NULL;
            IF COL_LENGTH(N'dbo.CheckoutCommands', 'CustomerName') IS NULL
                ALTER TABLE dbo.CheckoutCommands ADD CustomerName NVARCHAR(200) NULL;
            """, cancellationToken);

        await db.Database.ExecuteSqlRawAsync("""
            IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.CheckoutCommands') AND name = N'UX_CheckoutCommands_IdempotencyKey')
                CREATE UNIQUE INDEX UX_CheckoutCommands_IdempotencyKey ON dbo.CheckoutCommands(IdempotencyKey);

            IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.CheckoutCommands') AND name = N'IX_CheckoutCommands_CreatedAtUtc')
                CREATE INDEX IX_CheckoutCommands_CreatedAtUtc ON dbo.CheckoutCommands(CreatedAtUtc);
            """, cancellationToken);
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
        await db.Database.ExecuteSqlRawAsync("""
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
            END
            """, cancellationToken);

        await db.Database.ExecuteSqlRawAsync("""
            IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.OrderContextSnapshots') AND name = N'IX_OrderContextSnapshots_BranchId')
                CREATE INDEX IX_OrderContextSnapshots_BranchId ON dbo.OrderContextSnapshots(BranchId);

            IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.OrderContextSnapshots') AND name = N'IX_OrderContextSnapshots_RefreshedAtUtc')
                CREATE INDEX IX_OrderContextSnapshots_RefreshedAtUtc ON dbo.OrderContextSnapshots(RefreshedAtUtc);
            """, cancellationToken);
    }
}
