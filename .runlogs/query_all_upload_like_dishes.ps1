$ErrorActionPreference = "Stop"

function Invoke-ReaderRows {
    param(
        [Parameter(Mandatory = $true)][string]$Database,
        [Parameter(Mandatory = $true)][string]$Sql
    )

    $conn = New-Object System.Data.SqlClient.SqlConnection("Server=(localdb)\MSSQLLocalDB;Database=$Database;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=True")
    $conn.Open()
    try {
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = $Sql
        $cmd.CommandTimeout = 60
        $reader = $cmd.ExecuteReader()
        $rows = @()
        while ($reader.Read()) {
            $obj = [ordered]@{}
            for ($i = 0; $i -lt $reader.FieldCount; $i++) {
                $name = $reader.GetName($i)
                $value = if ($reader.IsDBNull($i)) { $null } else { $reader.GetValue($i) }
                $obj[$name] = $value
            }
            $rows += [pscustomobject]$obj
        }
        $reader.Close()
        return $rows
    }
    finally {
        $conn.Close()
    }
}

$dishSql = @"
SELECT d.DishID,d.Name,d.IsActive,d.Available
FROM Dishes d
WHERE d.Name LIKE N'%Dưa hấu%'
   OR d.Name LIKE N'DbgUpload%'
   OR d.Name LIKE N'UploadDish%'
ORDER BY d.DishID;
"@

$linkSql = @"
SELECT d.DishID, COUNT(*) AS LinkCount
FROM Dishes d
LEFT JOIN CategoryDish cd ON cd.DishID = d.DishID
WHERE d.Name LIKE N'%Dưa hấu%'
   OR d.Name LIKE N'DbgUpload%'
   OR d.Name LIKE N'UploadDish%'
GROUP BY d.DishID
ORDER BY d.DishID;
"@

$orderSql = @"
SELECT oi.DishID, COUNT(*) AS OrderItemCount
FROM OrderItems oi
WHERE oi.DishID IN (
    SELECT DishID
    FROM [RESTAURANT_CATALOG].dbo.Dishes
    WHERE Name LIKE N'%Dưa hấu%'
       OR Name LIKE N'DbgUpload%'
       OR Name LIKE N'UploadDish%'
)
GROUP BY oi.DishID
ORDER BY oi.DishID;
"@

[pscustomobject]@{
    Dishes = @(Invoke-ReaderRows -Database "RESTAURANT_CATALOG" -Sql $dishSql)
    Links = @(Invoke-ReaderRows -Database "RESTAURANT_CATALOG" -Sql $linkSql)
    Orders = @(Invoke-ReaderRows -Database "RESTAURANT_ORDERS" -Sql $orderSql)
} | ConvertTo-Json -Depth 10
