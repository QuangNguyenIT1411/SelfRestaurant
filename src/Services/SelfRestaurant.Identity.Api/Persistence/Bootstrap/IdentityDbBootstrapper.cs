using System.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
namespace SelfRestaurant.Identity.Api.Persistence;

public static class IdentityDbBootstrapper
{
    private static readonly string[] OwnedTables =
    [
        "CatalogBranchSnapshots",
        "Customers",
        "EmployeeRoles",
        "Employees",
        "PasswordResetTokens",
        "LoyaltyCards"
    ];

    public static async Task EnsureReadyAsync(
        IServiceProvider services,
        ILogger logger,
        CancellationToken cancellationToken = default)
    {
        using var scope = services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<IdentityDbContext>();

        await WaitForDatabaseAsync(db, logger, cancellationToken);
        await ValidateOwnedSchemaAsync(db, logger, cancellationToken);
        await SeedReferenceDataAsync(db, logger, cancellationToken);
    }

    private static async Task WaitForDatabaseAsync(IdentityDbContext db, ILogger logger, CancellationToken cancellationToken)
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

    private static Task SeedReferenceDataAsync(IdentityDbContext db, ILogger logger, CancellationToken cancellationToken)
    {
        logger.LogInformation("Identity reference seed skipped; service no longer owns OrderStatus.");
        return Task.CompletedTask;
    }

    private static async Task ValidateOwnedSchemaAsync(IdentityDbContext db, ILogger logger, CancellationToken cancellationToken)
    {
        var missing = new List<string>();
        foreach (var table in OwnedTables)
        {
            if (!await ObjectExistsAsync(db, table, requirePhysicalTable: true, cancellationToken))
            {
                missing.Add(table);
            }
        }

        if (missing.Count > 0)
        {
            throw new InvalidOperationException(
                "Identity storage is missing owned tables: " + string.Join(", ", missing) +
                ". Run sql/setup-service-db-shells.ps1 or complete the Identity DB cutover before starting Identity.Api.");
        }

        if (!await ObjectExistsAsync(db, "CustomerLoyalty", requirePhysicalTable: false, cancellationToken))
        {
            throw new InvalidOperationException("Identity storage is missing CustomerLoyalty view.");
        }

        logger.LogInformation("Identity schema validated without transitional Branches dependency.");
    }

    private static async Task<bool> ObjectExistsAsync(
        IdentityDbContext db,
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
}
