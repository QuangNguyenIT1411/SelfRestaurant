$ErrorActionPreference = "Stop"

$ids = "2142,2143,3145,3146,3147,3148,3150,3151,3152"

$conn = New-Object System.Data.SqlClient.SqlConnection("Server=(localdb)\MSSQLLocalDB;Database=RESTAURANT_CATALOG;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=True")
$conn.Open()

try {
    $tx = $conn.BeginTransaction()
    try {
        $cmd = $conn.CreateCommand()
        $cmd.Transaction = $tx
        $cmd.CommandTimeout = 120
        $cmd.CommandText = @"
DELETE FROM BusinessAuditLogs
WHERE DishId IN ($ids)
   OR (EntityType = 'DISH' AND TRY_CONVERT(int, EntityId) IN ($ids));

DELETE FROM CategoryDish
WHERE DishID IN ($ids);

DELETE FROM DishIngredients
WHERE DishID IN ($ids);

DELETE FROM Dishes
WHERE DishID IN ($ids);
"@
        [void]$cmd.ExecuteNonQuery()
        $tx.Commit()
    }
    catch {
        $tx.Rollback()
        throw
    }
}
finally {
    $conn.Close()
}

Write-Output "Cleanup completed for dish IDs: $ids"
