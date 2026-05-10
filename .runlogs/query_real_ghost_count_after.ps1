$ErrorActionPreference = 'Stop'
$c = New-Object System.Data.SqlClient.SqlConnection('Server=(localdb)\MSSQLLocalDB;Database=RESTAURANT_CATALOG;Trusted_Connection=True;TrustServerCertificate=True')
$c.Open()
try {
  $cmd = $c.CreateCommand()
  $cmd.CommandText = @"
SELECT COUNT(*)
FROM DiningTables t
JOIN TableStatus ts ON ts.StatusID=t.StatusID
WHERE ISNULL(t.IsActive,1)=1
  AND ts.StatusCode='OCCUPIED'
  AND t.CurrentOrderID IS NULL
  AND NOT EXISTS (
    SELECT 1
    FROM [RESTAURANT_ORDERS].dbo.Orders o
    JOIN [RESTAURANT_ORDERS].dbo.OrderStatus os ON os.StatusID=o.StatusID
    WHERE o.TableID=t.TableID
      AND ISNULL(o.IsActive,0)=1
      AND os.StatusCode IN ('PENDING','CONFIRMED','PREPARING','READY','SERVING')
  );
"@
  $cmd.CommandTimeout = 120
  Write-Output $cmd.ExecuteScalar()
}
finally { $c.Close() }
