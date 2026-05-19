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
        "DishIngredients",
        "IngredientBatches",
        "IngredientStockMovements",
        "Units"
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
        await EnsureTableNumberSchemaAsync(db, cancellationToken);
        await EnsureUnitsSchemaAsync(db, cancellationToken);
        await EnsureIngredientBatchSchemaAsync(db, cancellationToken);
        await ValidateOwnedSchemaAsync(db, logger, cancellationToken);
        await SeedReferenceDataAsync(db, logger, cancellationToken);
        await EnsureLogicalRecipeDataAsync(db, cancellationToken);
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

    private static async Task EnsureUnitsSchemaAsync(CatalogDbContext db, CancellationToken cancellationToken)
    {
        const string createSql = """
                                 IF OBJECT_ID(N'dbo.Units', N'U') IS NULL
                                 BEGIN
                                     CREATE TABLE dbo.Units
                                     (
                                         UnitID INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Units PRIMARY KEY,
                                         Name NVARCHAR(50) NOT NULL,
                                         Description NVARCHAR(500) NULL,
                                         DisplayOrder INT NOT NULL CONSTRAINT DF_Units_DisplayOrder DEFAULT(0),
                                         IsActive BIT NOT NULL CONSTRAINT DF_Units_IsActive DEFAULT(1),
                                         CreatedAt DATETIME NOT NULL CONSTRAINT DF_Units_CreatedAt DEFAULT(GETDATE()),
                                         UpdatedAt DATETIME NOT NULL CONSTRAINT DF_Units_UpdatedAt DEFAULT(GETDATE())
                                     );
                                 END
                                 """;

        const string indexSql = """
                                IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Units') AND name = N'UX_Units_Name')
                                    CREATE UNIQUE INDEX UX_Units_Name ON dbo.Units(Name);

                                IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Units') AND name = N'IX_Units_IsActive')
                                    CREATE INDEX IX_Units_IsActive ON dbo.Units(IsActive);
                                """;

        const string seedSql = """
                               ;WITH source_units AS
                               (
                                   SELECT DISTINCT LTRIM(RTRIM(Unit)) AS Name
                                   FROM dbo.Dishes
                                   WHERE Unit IS NOT NULL AND LTRIM(RTRIM(Unit)) <> N''

                                   UNION

                                   SELECT DISTINCT LTRIM(RTRIM(Unit)) AS Name
                                   FROM dbo.Ingredients
                                   WHERE Unit IS NOT NULL AND LTRIM(RTRIM(Unit)) <> N''
                               )
                               INSERT INTO dbo.Units(Name, Description, DisplayOrder, IsActive, CreatedAt, UpdatedAt)
                               SELECT Name, NULL, 0, 1, GETDATE(), GETDATE()
                               FROM source_units source
                               WHERE NOT EXISTS
                               (
                                   SELECT 1
                                   FROM dbo.Units units
                                   WHERE units.Name = source.Name
                               );
                               """;

        await db.Database.ExecuteSqlRawAsync(createSql, cancellationToken);
        await db.Database.ExecuteSqlRawAsync(indexSql, cancellationToken);
        await db.Database.ExecuteSqlRawAsync(seedSql, cancellationToken);
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

    private static async Task EnsureLogicalRecipeDataAsync(CatalogDbContext db, CancellationToken cancellationToken)
    {
        const string sql = """
                           IF NOT EXISTS (SELECT 1 FROM dbo.Ingredients WHERE Name = N'Nước dùng')
                           BEGIN
                               INSERT INTO dbo.Ingredients (Name, Unit, CurrentStock, ReorderLevel, IsActive)
                               VALUES (N'Nước dùng', N'lít', 60.00, 10.00, 1);
                           END;

                           IF NOT EXISTS (SELECT 1 FROM dbo.Ingredients WHERE Name = N'Đá')
                           BEGIN
                               INSERT INTO dbo.Ingredients (Name, Unit, CurrentStock, ReorderLevel, IsActive)
                               VALUES (N'Đá', N'kg', 80.00, 15.00, 1);
                           END;

                           IF NOT EXISTS (SELECT 1 FROM dbo.Ingredients WHERE Name = N'Sữa tươi')
                           BEGIN
                               INSERT INTO dbo.Ingredients (Name, Unit, CurrentStock, ReorderLevel, IsActive)
                               VALUES (N'Sữa tươi', N'lít', 25.00, 5.00, 1);
                           END;

                           DECLARE @BrothId INT = (SELECT TOP (1) IngredientID FROM dbo.Ingredients WHERE Name = N'Nước dùng');
                           DECLARE @IceId INT = (SELECT TOP (1) IngredientID FROM dbo.Ingredients WHERE Name = N'Đá');
                           DECLARE @MilkId INT = (SELECT TOP (1) IngredientID FROM dbo.Ingredients WHERE Name = N'Sữa tươi');

                           DECLARE @recipes TABLE
                           (
                               DishID INT NOT NULL,
                               IngredientID INT NOT NULL,
                               QuantityPerDish DECIMAL(18,2) NOT NULL,
                               PRIMARY KEY (DishID, IngredientID)
                           );

                           INSERT INTO @recipes (DishID, IngredientID, QuantityPerDish)
                           VALUES
                               (1, 1, 0.20), (1, 21, 0.30), (1, @BrothId, 0.50), (1, 7, 0.03), (1, 8, 0.02), (1, 9, 0.05), (1, 13, 0.02),
                               (2, 3, 0.15), (2, 22, 0.30), (2, 7, 0.08), (2, 11, 0.05), (2, 13, 0.03),
                               (3, 3, 0.15), (3, 25, 0.20), (3, 26, 1.00), (3, 11, 0.05), (3, 14, 0.02),
                               (4, 1, 0.18), (4, 22, 0.30), (4, @BrothId, 0.50), (4, 7, 0.05), (4, 8, 0.02), (4, 20, 0.01),
                               (5, 3, 0.10), (5, 4, 0.08), (5, 24, 0.30), (5, @BrothId, 0.45), (5, 7, 0.05), (5, 9, 0.05),
                               (6, 1, 0.15), (6, 23, 0.25), (6, 12, 0.08), (6, 10, 0.05), (6, 14, 0.03),
                               (7, 2, 0.25), (7, 25, 0.20), (7, 11, 0.05), (7, 7, 0.03),
                               (8, 3, 0.10), (8, 36, 0.05), (8, 26, 0.50), (8, 14, 0.05),
                               (9, 4, 0.08), (9, 37, 0.05), (9, 6, 0.05), (9, 7, 0.03),
                               (10, 6, 0.10), (10, 11, 0.05), (10, 10, 0.05), (10, 12, 0.05),
                               (11, 33, 0.10), (11, 32, 0.05), (11, 16, 0.03), (11, @MilkId, 0.10),
                               (12, 26, 2.00), (12, 30, 0.10), (12, 16, 0.05), (12, @MilkId, 0.15),
                               (13, 32, 0.08), (13, 33, 0.12), (13, 16, 0.04), (13, 34, 0.05),
                               (14, 27, 0.15), (14, 16, 0.02), (14, @IceId, 0.15),
                               (15, 31, 0.01), (15, 16, 0.01), (15, @IceId, 0.20),
                               (16, 29, 0.02), (16, 30, 0.05), (16, 16, 0.02), (16, @IceId, 0.20),
                               (17, 28, 0.20), (17, 30, 0.08), (17, 16, 0.03), (17, @IceId, 0.15),
                               (22, 5, 0.18), (22, 8, 0.02), (22, 18, 0.01), (22, 19, 0.01), (22, 14, 0.03), (22, 15, 0.01), (22, 17, 0.01);

                           DELETE di
                           FROM dbo.DishIngredients di
                           INNER JOIN @recipes r ON r.DishID = di.DishID
                           WHERE NOT EXISTS
                           (
                               SELECT 1
                               FROM @recipes keep
                               WHERE keep.DishID = di.DishID
                                 AND keep.IngredientID = di.IngredientID
                           );

                           UPDATE di
                           SET QuantityPerDish = r.QuantityPerDish
                           FROM dbo.DishIngredients di
                           INNER JOIN @recipes r
                               ON r.DishID = di.DishID
                              AND r.IngredientID = di.IngredientID
                           WHERE di.QuantityPerDish <> r.QuantityPerDish;

                           INSERT INTO dbo.DishIngredients (DishID, IngredientID, QuantityPerDish)
                           SELECT r.DishID, r.IngredientID, r.QuantityPerDish
                           FROM @recipes r
                           INNER JOIN dbo.Dishes d ON d.DishID = r.DishID
                           WHERE NOT EXISTS
                           (
                               SELECT 1
                               FROM dbo.DishIngredients di
                               WHERE di.DishID = r.DishID
                                 AND di.IngredientID = r.IngredientID
                           );
                           """;

        await db.Database.ExecuteSqlRawAsync(sql, cancellationToken);
    }

    private static async Task EnsureIngredientBatchSchemaAsync(CatalogDbContext db, CancellationToken cancellationToken)
    {
        const string createBatchesSql = """
                                        IF OBJECT_ID(N'dbo.IngredientBatches', N'U') IS NULL
                                        BEGIN
                                            CREATE TABLE dbo.IngredientBatches
                                            (
                                                BatchID INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_IngredientBatches PRIMARY KEY,
                                                IngredientID INT NOT NULL,
                                                BatchCode NVARCHAR(100) NULL,
                                                QuantityInitial DECIMAL(18,2) NOT NULL,
                                                QuantityRemaining DECIMAL(18,2) NOT NULL,
                                                Unit NVARCHAR(50) NOT NULL,
                                                ExpiryDate DATE NOT NULL,
                                                ReceivedDate DATE NOT NULL,
                                                SupplierName NVARCHAR(200) NULL,
                                                IsActive BIT NOT NULL CONSTRAINT DF_IngredientBatches_IsActive DEFAULT(1),
                                                CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_IngredientBatches_CreatedAt DEFAULT(SYSUTCDATETIME()),
                                                UpdatedAt DATETIME2 NULL,
                                                RowVersion ROWVERSION NOT NULL,
                                                CONSTRAINT FK_IngredientBatches_Ingredients FOREIGN KEY (IngredientID) REFERENCES dbo.Ingredients(IngredientID),
                                                CONSTRAINT CK_IngredientBatches_QuantityInitial_NonNegative CHECK (QuantityInitial >= 0),
                                                CONSTRAINT CK_IngredientBatches_QuantityRemaining_NonNegative CHECK (QuantityRemaining >= 0),
                                                CONSTRAINT CK_IngredientBatches_QuantityRemaining_MaxInitial CHECK (QuantityRemaining <= QuantityInitial)
                                            );
                                        END
                                        """;

        const string createMovementsSql = """
                                          IF OBJECT_ID(N'dbo.IngredientStockMovements', N'U') IS NULL
                                          BEGIN
                                              CREATE TABLE dbo.IngredientStockMovements
                                              (
                                                  MovementID BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_IngredientStockMovements PRIMARY KEY,
                                                  IngredientID INT NOT NULL,
                                                  BatchID INT NULL,
                                                  QuantityChange DECIMAL(18,2) NOT NULL,
                                                  MovementType NVARCHAR(50) NOT NULL,
                                                  ReferenceType NVARCHAR(50) NULL,
                                                  ReferenceID INT NULL,
                                                  OrderID INT NULL,
                                                  OrderItemID INT NULL,
                                                  DishID INT NULL,
                                                  CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_IngredientStockMovements_CreatedAt DEFAULT(SYSUTCDATETIME()),
                                                  Note NVARCHAR(500) NULL,
                                                  CONSTRAINT FK_IngredientStockMovements_Ingredients FOREIGN KEY (IngredientID) REFERENCES dbo.Ingredients(IngredientID),
                                                  CONSTRAINT FK_IngredientStockMovements_IngredientBatches FOREIGN KEY (BatchID) REFERENCES dbo.IngredientBatches(BatchID)
                                              );
                                          END
                                          """;

        const string indexSql = """
                                IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.IngredientBatches') AND name = N'IX_IngredientBatches_Ingredient_Fefo')
                                    CREATE INDEX IX_IngredientBatches_Ingredient_Fefo ON dbo.IngredientBatches(IngredientID, IsActive, ExpiryDate, ReceivedDate, BatchID);

                                IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.IngredientBatches') AND name = N'IX_IngredientBatches_ExpiryDate')
                                    CREATE INDEX IX_IngredientBatches_ExpiryDate ON dbo.IngredientBatches(ExpiryDate);

                                IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.IngredientStockMovements') AND name = N'IX_IngredientStockMovements_Ingredient_CreatedAt')
                                    CREATE INDEX IX_IngredientStockMovements_Ingredient_CreatedAt ON dbo.IngredientStockMovements(IngredientID, CreatedAt DESC);

                                IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.IngredientStockMovements') AND name = N'IX_IngredientStockMovements_BatchID')
                                    CREATE INDEX IX_IngredientStockMovements_BatchID ON dbo.IngredientStockMovements(BatchID);
                                """;

        await db.Database.ExecuteSqlRawAsync(createBatchesSql, cancellationToken);
        await db.Database.ExecuteSqlRawAsync(createMovementsSql, cancellationToken);
        await db.Database.ExecuteSqlRawAsync(indexSql, cancellationToken);
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
                                         BranchId INT NULL,
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

        const string addBranchIdColumnSql = """
                                            IF COL_LENGTH(N'dbo.BusinessAuditLogs', N'BranchId') IS NULL
                                            BEGIN
                                                ALTER TABLE dbo.BusinessAuditLogs ADD BranchId INT NULL;
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

                                IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.BusinessAuditLogs') AND name = N'IX_BusinessAuditLogs_BranchId')
                                    CREATE INDEX IX_BusinessAuditLogs_BranchId ON dbo.BusinessAuditLogs(BranchId);
                                """;

        await db.Database.ExecuteSqlRawAsync(createSql, cancellationToken);
        await db.Database.ExecuteSqlRawAsync(addBranchIdColumnSql, cancellationToken);
        await db.Database.ExecuteSqlRawAsync(indexSql, cancellationToken);
    }

    private static async Task EnsureTableNumberSchemaAsync(CatalogDbContext db, CancellationToken cancellationToken)
    {
        const string ensureColumnSql = """
                                       IF COL_LENGTH(N'dbo.DiningTables', N'TableNumber') IS NULL
                                       BEGIN
                                           ALTER TABLE dbo.DiningTables ADD TableNumber INT NULL;
                                       END
                                       """;

        const string backfillAndIndexSql = """
                                           ;WITH ordered AS
                                           (
                                               SELECT
                                                   TableID,
                                                   TableNumber = ROW_NUMBER() OVER (PARTITION BY BranchID ORDER BY TableID)
                                               FROM dbo.DiningTables
                                           )
                                           UPDATE dt
                                           SET
                                               dt.TableNumber = ordered.TableNumber
                                           FROM dbo.DiningTables dt
                                           INNER JOIN ordered ON ordered.TableID = dt.TableID
                                           WHERE dt.TableNumber IS NULL OR dt.TableNumber <= 0;

                                           IF EXISTS (SELECT 1 FROM dbo.DiningTables WHERE TableNumber IS NULL OR TableNumber <= 0)
                                           BEGIN
                                               THROW 50001, N'Không thể khởi tạo số bàn theo chi nhánh.', 1;
                                           END

                                           IF NOT EXISTS
                                           (
                                               SELECT 1
                                               FROM sys.indexes
                                               WHERE object_id = OBJECT_ID(N'dbo.DiningTables')
                                                 AND name = N'UQ_DiningTables_Branch_TableNumber'
                                           )
                                           BEGIN
                                               CREATE UNIQUE INDEX UQ_DiningTables_Branch_TableNumber
                                                   ON dbo.DiningTables(BranchID, TableNumber);
                                           END
                                           """;

        const string syncViewSql = """
                                   IF OBJECT_ID(N'dbo.TableNumbers', N'V') IS NOT NULL
                                   BEGIN
                                       EXEC(N'
                                           ALTER VIEW dbo.TableNumbers AS
                                           SELECT
                                               dt.TableID,
                                               dt.BranchID,
                                               b.Name AS BranchName,
                                               dt.TableNumber,
                                               dt.NumberOfSeats,
                                               dt.QRCode,
                                               ts.StatusName,
                                               dt.CurrentOrderID,
                                               dt.IsActive
                                           FROM dbo.DiningTables dt
                                           INNER JOIN dbo.Branches b ON dt.BranchID = b.BranchID
                                           INNER JOIN dbo.TableStatus ts ON dt.StatusID = ts.StatusID;
                                       ');
                                   END
                                   """;

        await db.Database.ExecuteSqlRawAsync(ensureColumnSql, cancellationToken);
        await db.Database.ExecuteSqlRawAsync(backfillAndIndexSql, cancellationToken);
        await db.Database.ExecuteSqlRawAsync(syncViewSql, cancellationToken);
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
