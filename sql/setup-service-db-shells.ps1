param(
    [string]$Server = "(localdb)\\MSSQLLocalDB",
    [string]$MasterDatabase = "RESTAURANT"
)

$ErrorActionPreference = "Stop"

function Get-SqlCmdPath {
    $candidates = @(
        "sqlcmd",
        "C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\SQLCMD.EXE",
        "C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\180\Tools\Binn\SQLCMD.EXE"
    )

    foreach ($candidate in $candidates) {
        try {
            $command = Get-Command $candidate -ErrorAction Stop
            return $command.Source
        }
        catch {
            if (Test-Path $candidate) {
                return $candidate
            }
        }
    }

    throw "sqlcmd was not found. Install SQL Server command line tools or update setup-service-db-shells.ps1 with the installed path."
}

$serviceDatabases = @(
    "RESTAURANT_CATALOG",
    "RESTAURANT_ORDERS",
    "RESTAURANT_CUSTOMERS",
    "RESTAURANT_IDENTITY",
    "RESTAURANT_BILLING"
)

$createDatabasesSql = @(
    "IF DB_ID('$MasterDatabase') IS NULL THROW 50000, 'Master database $MasterDatabase does not exist.', 1;"
)

foreach ($db in $serviceDatabases) {
    $createDatabasesSql += "IF DB_ID('$db') IS NULL CREATE DATABASE [$db];"
}

$sqlcmd = Get-SqlCmdPath
& $sqlcmd -S $Server -E -Q ($createDatabasesSql -join " ")

$syncObjectsSql = @"
SET NOCOUNT ON;

DECLARE @master sysname = N'$MasterDatabase';
DECLARE @target sysname = DB_NAME();
DECLARE @sql nvarchar(max) = N'';

SELECT @sql = @sql +
    N'IF EXISTS (SELECT 1 FROM sys.synonyms WHERE name = N''' + o.name + N''' AND schema_id = SCHEMA_ID(N''dbo'')) ' +
    N'DROP SYNONYM dbo.' + QUOTENAME(o.name) + N';' + CHAR(10)
FROM
(
    SELECT name FROM [$MasterDatabase].sys.tables WHERE schema_id = SCHEMA_ID(N'dbo')
    UNION
    SELECT name FROM [$MasterDatabase].sys.views WHERE schema_id = SCHEMA_ID(N'dbo')
) AS o;

EXEC sp_executesql @sql;

SET @sql = N'';

SELECT @sql = @sql +
    N'CREATE SYNONYM dbo.' + QUOTENAME(o.name) + N' FOR ' + QUOTENAME(@master) + N'.dbo.' + QUOTENAME(o.name) + N';' + CHAR(10)
FROM
(
    SELECT name FROM [$MasterDatabase].sys.tables WHERE schema_id = SCHEMA_ID(N'dbo')
    UNION
    SELECT name FROM [$MasterDatabase].sys.views WHERE schema_id = SCHEMA_ID(N'dbo')
) AS o
ORDER BY o.name;

EXEC sp_executesql @sql;
"@

foreach ($db in $serviceDatabases) {
    Write-Host "Preparing service database shell: $db"
    & $sqlcmd -S $Server -E -d $db -Q $syncObjectsSql -b
}

Write-Host "OK: service database shells are ready on $Server"
