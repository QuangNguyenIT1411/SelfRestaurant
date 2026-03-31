param(
    [string]$ConnectionString = "Server=(localdb)\MSSQLLocalDB;Database=RESTAURANT;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=True",
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

function Invoke-NonQuery {
    param(
        [Parameter(Mandatory = $true)]
        [System.Data.SqlClient.SqlConnection]$Connection,
        [System.Data.SqlClient.SqlTransaction]$Transaction,
        [Parameter(Mandatory = $true)]
        [string]$Sql
    )

    $cmd = $Connection.CreateCommand()
    if ($null -ne $Transaction) {
        $cmd.Transaction = $Transaction
    }
    $cmd.CommandText = $Sql
    $cmd.CommandTimeout = 120
    return $cmd.ExecuteNonQuery()
}

function Invoke-Scalar {
    param(
        [Parameter(Mandatory = $true)]
        [System.Data.SqlClient.SqlConnection]$Connection,
        [Parameter(Mandatory = $true)]
        [string]$Sql
    )

    $cmd = $Connection.CreateCommand()
    $cmd.CommandText = $Sql
    $cmd.CommandTimeout = 120
    return $cmd.ExecuteScalar()
}

function New-UnicodeString {
    param([int[]]$CodePoints)
    return -join ($CodePoints | ForEach-Object { [char]$_ })
}

function Update-BaselineCategory {
    param(
        [Parameter(Mandatory = $true)]
        [System.Data.SqlClient.SqlConnection]$Connection,
        [Parameter(Mandatory = $true)]
        [System.Data.SqlClient.SqlTransaction]$Transaction,
        [Parameter(Mandatory = $true)]
        [int]$CategoryId,
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [string]$Description,
        [Parameter(Mandatory = $true)]
        [int]$DisplayOrder
    )

    $cmd = $Connection.CreateCommand()
    $cmd.Transaction = $Transaction
    $cmd.CommandTimeout = 120
    $cmd.CommandText = @"
UPDATE Categories
SET Name = @name,
    Description = @description,
    DisplayOrder = @displayOrder,
    IsActive = 1,
    UpdatedAt = GETDATE()
WHERE CategoryID = @categoryId;
"@
    [void]$cmd.Parameters.Add("@name", [System.Data.SqlDbType]::NVarChar, 200)
    [void]$cmd.Parameters.Add("@description", [System.Data.SqlDbType]::NVarChar, 1000)
    [void]$cmd.Parameters.Add("@displayOrder", [System.Data.SqlDbType]::Int)
    [void]$cmd.Parameters.Add("@categoryId", [System.Data.SqlDbType]::Int)

    $cmd.Parameters["@name"].Value = $Name
    $cmd.Parameters["@description"].Value = $Description
    $cmd.Parameters["@displayOrder"].Value = $DisplayOrder
    $cmd.Parameters["@categoryId"].Value = $CategoryId

    [void]$cmd.ExecuteNonQuery()
}

$conn = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
$conn.Open()

try {
    $beforeAutoCats = [int](Invoke-Scalar -Connection $conn -Sql @"
SELECT COUNT(*) FROM Categories WHERE Name LIKE 'AUTO[_]%' OR Name LIKE 'DBG[_]%' OR Name LIKE 'CODEX[_]%'
"@)
    $beforeAutoDishes = [int](Invoke-Scalar -Connection $conn -Sql @"
SELECT COUNT(*) FROM Dishes WHERE Name LIKE 'AUTO[_]%' OR Name LIKE 'DBG[_]%' OR Name LIKE 'CODEX[_]%'
"@)

    Write-Host "Before cleanup: auto/debug categories=$beforeAutoCats, auto/debug dishes=$beforeAutoDishes"

    if ($WhatIf) {
        Write-Host "WhatIf enabled. No data changed."
        return
    }

    $tx = $conn.BeginTransaction()
    try {
        # 1) Restore baseline category names/order for the main flows.
        Update-BaselineCategory -Connection $conn -Transaction $tx -CategoryId 1 -DisplayOrder 1 `
            -Name (New-UnicodeString @(77,243,110,32,99,104,237,110,104)) `
            -Description (New-UnicodeString @(67,225,99,32,109,243,110,32,259,110,32,99,104,237,110,104))

        Update-BaselineCategory -Connection $conn -Transaction $tx -CategoryId 2 -DisplayOrder 2 `
            -Name (New-UnicodeString @(77,243,110,32,112,104,7909)) `
            -Description (New-UnicodeString @(67,225,99,32,109,243,110,32,259,110,32,112,104,7909))

        Update-BaselineCategory -Connection $conn -Transaction $tx -CategoryId 3 -DisplayOrder 3 `
            -Name (New-UnicodeString @(84,114,225,110,103,32,109,105,7879,110,103)) `
            -Description (New-UnicodeString @(67,225,99,32,109,243,110,32,116,114,225,110,103,32,109,105,7879,110,103))

        Update-BaselineCategory -Connection $conn -Transaction $tx -CategoryId 4 -DisplayOrder 4 `
            -Name (New-UnicodeString @(272,7891,32,117,7889,110,103)) `
            -Description (New-UnicodeString @(67,225,99,32,108,111,7841,105,32,273,7891,32,117,7889,110,103))

        # 2) Disable test categories to prevent leaking into admin/customer views.
        Invoke-NonQuery -Connection $conn -Transaction $tx -Sql @"
UPDATE Categories
SET IsActive = 0,
    UpdatedAt = GETDATE()
WHERE CategoryID NOT IN (1, 2, 3, 4)
  AND (
      Name LIKE 'AUTO[_]%'
      OR Name LIKE 'DBG[_]%'
      OR Name LIKE 'CODEX[_]%'
  );
"@ | Out-Null

        # 3) Disable test dishes and dishes attached to disabled/non-baseline categories.
        Invoke-NonQuery -Connection $conn -Transaction $tx -Sql @"
UPDATE d
SET d.IsActive = 0,
    d.Available = 0,
    d.UpdatedAt = GETDATE()
FROM Dishes d
LEFT JOIN Categories c ON c.CategoryID = d.CategoryID
WHERE d.Name LIKE 'AUTO[_]%'
   OR d.Name LIKE 'DBG[_]%'
   OR d.Name LIKE 'CODEX[_]%'
   OR d.CategoryID NOT IN (1, 2, 3, 4)
   OR ISNULL(c.IsActive, 0) = 0;
"@ | Out-Null

        # 4) Keep baseline menu categories active.
        Invoke-NonQuery -Connection $conn -Transaction $tx -Sql @"
UPDATE MenuCategory
SET IsActive = 1,
    UpdatedAt = GETDATE()
WHERE CategoryID IN (1, 2, 3, 4);
"@ | Out-Null

        # 5) Disable category-dish mappings when either side is disabled.
        Invoke-NonQuery -Connection $conn -Transaction $tx -Sql @"
UPDATE cd
SET cd.IsAvailable = 0,
    cd.UpdatedAt = GETDATE()
FROM CategoryDish cd
JOIN Dishes d ON d.DishID = cd.DishID
JOIN MenuCategory mc ON mc.MenuCategoryID = cd.MenuCategoryID
JOIN Categories c ON c.CategoryID = mc.CategoryID
WHERE ISNULL(d.IsActive, 0) = 0
   OR ISNULL(d.Available, 0) = 0
   OR ISNULL(mc.IsActive, 0) = 0
   OR ISNULL(c.IsActive, 0) = 0;
"@ | Out-Null

        $tx.Commit()
    }
    catch {
        $tx.Rollback()
        throw
    }

    $afterAutoCats = [int](Invoke-Scalar -Connection $conn -Sql @"
SELECT COUNT(*) FROM Categories WHERE IsActive = 1 AND (Name LIKE 'AUTO[_]%' OR Name LIKE 'DBG[_]%' OR Name LIKE 'CODEX[_]%')
"@)
    $afterAutoDishes = [int](Invoke-Scalar -Connection $conn -Sql @"
SELECT COUNT(*) FROM Dishes WHERE ISNULL(IsActive, 1) = 1 AND (Name LIKE 'AUTO[_]%' OR Name LIKE 'DBG[_]%' OR Name LIKE 'CODEX[_]%')
"@)

    Write-Host "After cleanup: active auto/debug categories=$afterAutoCats, active auto/debug dishes=$afterAutoDishes"
    Write-Host "Cleanup completed."
}
finally {
    $conn.Close()
}
