using System.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using SelfRestaurant.Catalog.Api.Persistence.Entities;

namespace SelfRestaurant.Catalog.Api.Persistence;

public static class CatalogDbBootstrapper
{
    private static readonly string[] OwnedTables =
    [
        "Restaurants",
        "Branches",
        "Categories",
        "Ingredients",
        "Dishes",
        "TableStatus",
        "DiningTables",
        "Menus",
        "MenuCategory",
        "CategoryDish",
        "DishIngredients"
    ];

    public static async Task EnsureReadyAsync(
        IServiceProvider services,
        ILogger logger,
        CancellationToken cancellationToken = default)
    {
        using var scope = services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<CatalogDbContext>();

        await WaitForDatabaseAsync(db, logger, cancellationToken);
        await EnsureBusinessAuditTableAsync(db, cancellationToken);
        await ValidateOwnedSchemaAsync(db, logger, cancellationToken);
        await SeedReferenceDataAsync(db, logger, cancellationToken);
    }

    private static async Task WaitForDatabaseAsync(CatalogDbContext db, ILogger logger, CancellationToken cancellationToken)
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

    private static async Task SeedReferenceDataAsync(CatalogDbContext db, ILogger logger, CancellationToken cancellationToken)
    {
        var changed = false;

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

    private static async Task EnsureBusinessAuditTableAsync(CatalogDbContext db, CancellationToken cancellationToken)
    {
        const string createSql = """
                                 IF OBJECT_ID(N'dbo.BusinessAuditLogs', N'U') IS NULL
                                 BEGIN
                                     CREATE TABLE dbo.BusinessAuditLogs
                                     (
                                         BusinessAuditLogId BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
                                         CreatedAtUtc DATETIME2 NOT NULL CONSTRAINT DF_CatalogBusinessAuditLogs_CreatedAtUtc DEFAULT (SYSUTCDATETIME()),
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

                                IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.BusinessAuditLogs') AND name = N'IX_BusinessAuditLogs_DishId')
                                    CREATE INDEX IX_BusinessAuditLogs_DishId ON dbo.BusinessAuditLogs(DishId);

                                IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.BusinessAuditLogs') AND name = N'IX_BusinessAuditLogs_TableId')
                                    CREATE INDEX IX_BusinessAuditLogs_TableId ON dbo.BusinessAuditLogs(TableId);
                                """;

        await db.Database.ExecuteSqlRawAsync(createSql, cancellationToken);
        await db.Database.ExecuteSqlRawAsync(indexSql, cancellationToken);
    }

    private static async Task ValidateOwnedSchemaAsync(CatalogDbContext db, ILogger logger, CancellationToken cancellationToken)
    {
        var missing = new List<string>();
        foreach (var table in OwnedTables)
        {
            if (!await TableExistsAsync(db, table, requirePhysicalTable: true, cancellationToken))
            {
                missing.Add(table);
            }
        }

        if (missing.Count > 0)
        {
            throw new InvalidOperationException(
                "Catalog storage is missing owned tables: " + string.Join(", ", missing) +
                ". Run sql/setup-service-db-shells.ps1 or complete the Catalog DB cutover before starting Catalog.Api.");
        }

        if (await TableExistsAsync(db, "__CatalogOwnershipState", requirePhysicalTable: true, cancellationToken))
        {
            logger.LogInformation("Catalog ownership state table detected.");
        }
        else
        {
            logger.LogWarning("Catalog ownership state table was not found. Initial shell materialization may not have completed.");
        }
    }

    private static async Task<bool> TableExistsAsync(CatalogDbContext db, string tableName, CancellationToken cancellationToken)
        => await TableExistsAsync(db, tableName, requirePhysicalTable: false, cancellationToken);

    private static async Task<bool> TableExistsAsync(CatalogDbContext db, string tableName, bool requirePhysicalTable, CancellationToken cancellationToken)
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
                    AND name = @table
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
}
