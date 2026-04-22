using System.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using SelfRestaurant.Orders.Api.Persistence.Entities;

namespace SelfRestaurant.Orders.Api.Persistence;

public static class OrdersDbBootstrapper
{
    private static readonly string[] OwnedWriteTables =
    [
        "Orders",
        "OrderItems",
        "OrderStatus",
        "BusinessAuditLogs",
        "SubmitCommands",
        "InboxEvents",
        "OutboxEvents"
    ];

    private static readonly string[] OwnedReadModelTables =
    [
        "CatalogBranchSnapshots",
        "CatalogDishSnapshots",
        "CatalogTableSnapshots"
    ];

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
        await EnsureCatalogSnapshotTablesAsync(db, cancellationToken);
        await EnsureOrdersDiningSessionColumnsAsync(db, cancellationToken);
        await EnsureOrderItemStatusColumnAsync(db, cancellationToken);
        await EnsureBusinessAuditTableAsync(db, cancellationToken);
        await EnsureSubmitCommandTableAsync(db, cancellationToken);
        await ValidateOwnedSchemaAsync(db, logger, cancellationToken);
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

    private static async Task EnsureBusinessAuditTableAsync(OrdersDbContext db, CancellationToken cancellationToken)
    {
        const string createSql = """
                                 IF OBJECT_ID(N'dbo.BusinessAuditLogs', N'U') IS NULL
                                 BEGIN
                                     CREATE TABLE dbo.BusinessAuditLogs
                                     (
                                         BusinessAuditLogId BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
                                         CreatedAtUtc DATETIME2 NOT NULL CONSTRAINT DF_OrdersBusinessAuditLogs_CreatedAtUtc DEFAULT (SYSUTCDATETIME()),
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

        const string indexesSql = """
                                  IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.BusinessAuditLogs') AND name = N'IX_BusinessAuditLogs_CreatedAtUtc')
                                      CREATE INDEX IX_BusinessAuditLogs_CreatedAtUtc ON dbo.BusinessAuditLogs(CreatedAtUtc);

                                  IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.BusinessAuditLogs') AND name = N'IX_BusinessAuditLogs_Entity')
                                      CREATE INDEX IX_BusinessAuditLogs_Entity ON dbo.BusinessAuditLogs(EntityType, EntityId);

                                  IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.BusinessAuditLogs') AND name = N'IX_BusinessAuditLogs_OrderId')
                                      CREATE INDEX IX_BusinessAuditLogs_OrderId ON dbo.BusinessAuditLogs(OrderId);

                                  IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.BusinessAuditLogs') AND name = N'IX_BusinessAuditLogs_TableId')
                                      CREATE INDEX IX_BusinessAuditLogs_TableId ON dbo.BusinessAuditLogs(TableId);
                                  """;

        await db.Database.ExecuteSqlRawAsync(createSql, cancellationToken);
        await db.Database.ExecuteSqlRawAsync(indexesSql, cancellationToken);
    }


    private static async Task ValidateOwnedSchemaAsync(OrdersDbContext db, ILogger logger, CancellationToken cancellationToken)
    {
        var missingWriteTables = new List<string>();
        foreach (var table in OwnedWriteTables)
        {
            if (!await ObjectExistsAsync(db, table, requirePhysicalTable: true, cancellationToken))
            {
                missingWriteTables.Add(table);
            }
        }

        if (missingWriteTables.Count > 0)
        {
            throw new InvalidOperationException(
                "Orders storage is missing owned write tables: " + string.Join(", ", missingWriteTables) +
                ". Complete the Orders DB cutover or materialize owned tables before starting Orders.Api.");
        }

        var missingReadModels = new List<string>();
        foreach (var table in OwnedReadModelTables)
        {
            if (!await ObjectExistsAsync(db, table, requirePhysicalTable: true, cancellationToken))
            {
                missingReadModels.Add(table);
            }
        }

        if (missingReadModels.Count > 0)
        {
            throw new InvalidOperationException(
                "Orders storage is missing local catalog snapshot tables: " + string.Join(", ", missingReadModels) +
                ". Ensure catalog read-model tables are created before starting Orders.Api.");
        }

        logger.LogInformation(
            "Orders write-model validated. Write tables: {WriteTables}. Read-model tables: {ReadModelTables}.",
            string.Join(", ", OwnedWriteTables),
            string.Join(", ", OwnedReadModelTables));
    }

    private static async Task<bool> ObjectExistsAsync(
        OrdersDbContext db,
        string objectName,
        bool requirePhysicalTable,
        CancellationToken cancellationToken)
    {
        await db.Database.OpenConnectionAsync(cancellationToken);
        try
        {
            await using var command = db.Database.GetDbConnection().CreateCommand();
            command.CommandText = requirePhysicalTable
                ? """
                  SELECT 1
                  FROM sys.tables
                  WHERE schema_id = SCHEMA_ID('dbo')
                    AND name = @name
                  """
                : """
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
                  WHERE name = @name
                  """;
            var parameter = command.CreateParameter();
            parameter.ParameterName = "@name";
            parameter.Value = objectName;
            command.Parameters.Add(parameter);

            var result = await command.ExecuteScalarAsync(cancellationToken);
            return result is not null;
        }
        finally
        {
            await db.Database.CloseConnectionAsync();
        }
    }

    private static async Task SeedReferenceDataAsync(OrdersDbContext db, ILogger logger, CancellationToken cancellationToken)
    {
        if (!await TableExistsAsync(db, "OrderStatus", cancellationToken))
        {
            logger.LogWarning("Missing expected tables; skipping seed.");
            return;
        }

        var changed = false;

        try
        {
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
        }
        catch (Exception ex) when (IsInvalidObjectReference(ex, "OrderStatus"))
        {
            logger.LogWarning(ex, "OrderStatus backing object is unavailable; skipping reference seed.");
            return;
        }

        if (changed)
        {
            await db.SaveChangesAsync(cancellationToken);
        }
    }

    private static bool IsInvalidObjectReference(Exception ex, string objectName)
    {
        var message = ex.GetBaseException().Message ?? string.Empty;
        return message.Contains("Invalid object name", StringComparison.OrdinalIgnoreCase)
               && message.Contains(objectName, StringComparison.OrdinalIgnoreCase);
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

            IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.OutboxEvents') AND name = N'IX_OutboxEvents_Status_EventName_CreatedAtUtc')
                CREATE INDEX IX_OutboxEvents_Status_EventName_CreatedAtUtc ON dbo.OutboxEvents(Status, EventName, CreatedAtUtc);
            """, cancellationToken);

        await db.Database.ExecuteSqlRawAsync("""
            UPDATE dbo.OutboxEvents
            SET Status = 'PROCESSED',
                ProcessedAtUtc = ISNULL(ProcessedAtUtc, SYSUTCDATETIME()),
                Error = COALESCE(NULLIF(Error, ''), 'AUTO:untracked-event')
            WHERE Status = 'PENDING'
              AND EventName <> 'order.status-ready.v1';
            """, cancellationToken);
    }

    private static async Task EnsureOrdersDiningSessionColumnsAsync(OrdersDbContext db, CancellationToken cancellationToken)
    {
        // Keep add-column and later references in separate batches; older SQL Server schemas can
        // parse the later index statement before ALTER TABLE takes effect.
        await db.Database.ExecuteSqlRawAsync("""
            IF COL_LENGTH('dbo.Orders', 'DiningSessionCode') IS NULL
                EXEC(N'ALTER TABLE dbo.Orders ADD DiningSessionCode VARCHAR(64) NULL;');
            """, cancellationToken);

        await db.Database.ExecuteSqlRawAsync("""
            IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Orders') AND name = N'idx_orders_session')
                CREATE INDEX idx_orders_session ON dbo.Orders(DiningSessionCode);
            """, cancellationToken);

        await db.Database.ExecuteSqlRawAsync("""
            IF COL_LENGTH('dbo.Orders', 'SubmitIdempotencyKey') IS NULL
                EXEC(N'ALTER TABLE dbo.Orders ADD SubmitIdempotencyKey VARCHAR(100) NULL;');
            """, cancellationToken);

        await db.Database.ExecuteSqlRawAsync("""
            IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Orders') AND name = N'UX_Orders_SubmitIdempotencyKey')
                CREATE UNIQUE INDEX UX_Orders_SubmitIdempotencyKey ON dbo.Orders(SubmitIdempotencyKey) WHERE SubmitIdempotencyKey IS NOT NULL;
            """, cancellationToken);
    }

    private static async Task EnsureOrderItemStatusColumnAsync(OrdersDbContext db, CancellationToken cancellationToken)
    {
        await db.Database.ExecuteSqlRawAsync("""
            IF COL_LENGTH('dbo.OrderItems', 'StatusCode') IS NULL
                EXEC(N'ALTER TABLE dbo.OrderItems ADD StatusCode VARCHAR(30) NOT NULL CONSTRAINT DF_OrderItems_StatusCode DEFAULT (''PENDING'');');
            """, cancellationToken);

        await db.Database.ExecuteSqlRawAsync("""
            UPDATE oi
            SET StatusCode =
                CASE UPPER(ISNULL(os.StatusCode, 'PENDING'))
                    WHEN 'CANCELLED' THEN 'CANCELLED'
                    WHEN 'COMPLETED' THEN 'SERVING'
                    WHEN 'SERVING' THEN 'SERVING'
                    WHEN 'READY' THEN 'READY'
                    WHEN 'PREPARING' THEN 'PREPARING'
                    WHEN 'CONFIRMED' THEN 'CONFIRMED'
                    ELSE 'PENDING'
                END
            FROM dbo.OrderItems oi
            INNER JOIN dbo.Orders o ON o.OrderID = oi.OrderID
            LEFT JOIN dbo.OrderStatus os ON os.StatusID = o.StatusID
            WHERE oi.StatusCode IS NULL
               OR LTRIM(RTRIM(oi.StatusCode)) = '';
            """, cancellationToken);
    }

    private static async Task EnsureSubmitCommandTableAsync(OrdersDbContext db, CancellationToken cancellationToken)
    {
        await db.Database.ExecuteSqlRawAsync("""
            IF OBJECT_ID(N'dbo.SubmitCommands', N'U') IS NULL
            BEGIN
                CREATE TABLE dbo.SubmitCommands
                (
                    SubmitCommandId BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
                    IdempotencyKey VARCHAR(100) NOT NULL,
                    TableId INT NOT NULL,
                    DiningSessionCode VARCHAR(64) NULL,
                    OrderId INT NULL,
                    Status VARCHAR(20) NOT NULL CONSTRAINT DF_SubmitCommands_Status DEFAULT ('PENDING'),
                    CreatedAtUtc DATETIME2 NOT NULL CONSTRAINT DF_SubmitCommands_CreatedAtUtc DEFAULT (SYSUTCDATETIME()),
                    CompletedAtUtc DATETIME2 NULL,
                    Error NVARCHAR(MAX) NULL
                );
            END
            """, cancellationToken);

        await db.Database.ExecuteSqlRawAsync("""
            IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.SubmitCommands') AND name = N'UX_SubmitCommands_IdempotencyKey')
                CREATE UNIQUE INDEX UX_SubmitCommands_IdempotencyKey ON dbo.SubmitCommands(IdempotencyKey);

            IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.SubmitCommands') AND name = N'IX_SubmitCommands_CreatedAtUtc')
                CREATE INDEX IX_SubmitCommands_CreatedAtUtc ON dbo.SubmitCommands(CreatedAtUtc);
            """, cancellationToken);
    }

    private static async Task EnsureInboxTableAsync(OrdersDbContext db, CancellationToken cancellationToken)
    {
        await db.Database.ExecuteSqlRawAsync("""
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
            END
            """, cancellationToken);

        await db.Database.ExecuteSqlRawAsync("""
            IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.InboxEvents') AND name = N'UX_InboxEvents_Source_SourceEventId')
                CREATE UNIQUE INDEX UX_InboxEvents_Source_SourceEventId ON dbo.InboxEvents(Source, SourceEventId);

            IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.InboxEvents') AND name = N'IX_InboxEvents_ReceivedAtUtc')
                CREATE INDEX IX_InboxEvents_ReceivedAtUtc ON dbo.InboxEvents(ReceivedAtUtc);
            """, cancellationToken);

        await db.Database.ExecuteSqlRawAsync("""
            IF COL_LENGTH('dbo.InboxEvents', 'RetryCount') IS NULL
            BEGIN
                ALTER TABLE dbo.InboxEvents ADD RetryCount INT NOT NULL CONSTRAINT DF_InboxEvents_RetryCount_Migrate DEFAULT (0);
            END

            IF COL_LENGTH('dbo.InboxEvents', 'NextRetryAtUtc') IS NULL
            BEGIN
                ALTER TABLE dbo.InboxEvents ADD NextRetryAtUtc DATETIME2 NULL;
            END
            """, cancellationToken);
    }

    private static async Task EnsureCatalogSnapshotTablesAsync(OrdersDbContext db, CancellationToken cancellationToken)
    {
        const string sql = """
                           IF OBJECT_ID(N'dbo.CatalogDishSnapshots', N'U') IS NULL
                           BEGIN
                               CREATE TABLE dbo.CatalogDishSnapshots
                               (
                                   DishId INT NOT NULL PRIMARY KEY,
                                   Name NVARCHAR(200) NOT NULL,
                                   CategoryId INT NOT NULL,
                                   CategoryName NVARCHAR(200) NULL,
                                   Price DECIMAL(18,2) NOT NULL,
                                   Unit NVARCHAR(50) NULL,
                                   Image NVARCHAR(500) NULL,
                                   IsActive BIT NOT NULL,
                                   Available BIT NOT NULL,
                                   RefreshedAtUtc DATETIME2 NOT NULL
                               );
                           END

                           IF OBJECT_ID(N'dbo.CatalogTableSnapshots', N'U') IS NULL
                           BEGIN
                               CREATE TABLE dbo.CatalogTableSnapshots
                               (
                                   TableId INT NOT NULL PRIMARY KEY,
                                   BranchId INT NOT NULL,
                                   QrCode NVARCHAR(100) NULL,
                                   IsActive BIT NOT NULL,
                                   StatusId INT NOT NULL,
                                   StatusCode NVARCHAR(50) NULL,
                                   StatusName NVARCHAR(100) NULL,
                                   RefreshedAtUtc DATETIME2 NOT NULL
                               );
                           END

                           IF OBJECT_ID(N'dbo.CatalogBranchSnapshots', N'U') IS NULL
                           BEGIN
                               CREATE TABLE dbo.CatalogBranchSnapshots
                               (
                                   BranchId INT NOT NULL PRIMARY KEY,
                                   Name NVARCHAR(200) NOT NULL,
                                   Location NVARCHAR(500) NULL,
                                   IsActive BIT NOT NULL,
                                   RefreshedAtUtc DATETIME2 NOT NULL
                               );
                           END
                           """;

        await db.Database.ExecuteSqlRawAsync(sql, cancellationToken);
    }
}
