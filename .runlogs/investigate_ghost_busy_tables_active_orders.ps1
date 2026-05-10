$ErrorActionPreference='Stop'
function Conn($db){$c=New-Object System.Data.SqlClient.SqlConnection("Server=(localdb)\MSSQLLocalDB;Database=$db;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=True");$c.Open();$c}
function Query($conn,$sql){$cmd=$conn.CreateCommand();$cmd.CommandText=$sql;$cmd.CommandTimeout=120;$da=New-Object System.Data.SqlClient.SqlDataAdapter($cmd);$dt=New-Object System.Data.DataTable;[void]$da.Fill($dt);$dt}
$catalog=Conn 'RESTAURANT_CATALOG'
try {
$dt=Query $catalog @"
SELECT t.TableID,t.BranchID,ts.StatusCode,t.CurrentOrderID,
       (SELECT COUNT(*) FROM [RESTAURANT_ORDERS].dbo.Orders o INNER JOIN [RESTAURANT_ORDERS].dbo.OrderStatus os ON os.StatusID=o.StatusID WHERE o.TableID=t.TableID AND ISNULL(o.IsActive,0)=1 AND os.StatusCode IN ('PENDING','CONFIRMED','PREPARING','READY','SERVING')) AS ActiveOrderCountByTable,
       (SELECT STRING_AGG(CONCAT(o.OrderID,':',os.StatusCode), ',') FROM [RESTAURANT_ORDERS].dbo.Orders o INNER JOIN [RESTAURANT_ORDERS].dbo.OrderStatus os ON os.StatusID=o.StatusID WHERE o.TableID=t.TableID AND ISNULL(o.IsActive,0)=1 AND os.StatusCode IN ('PENDING','CONFIRMED','PREPARING','READY','SERVING')) AS ActiveOrders
FROM DiningTables t
LEFT JOIN TableStatus ts ON ts.StatusID=t.StatusID
WHERE ISNULL(t.IsActive,1)=1 AND ts.StatusCode='OCCUPIED' AND t.CurrentOrderID IS NULL
ORDER BY t.BranchID,t.TableID;
"@
$dt | ConvertTo-Json -Depth 5
}
finally {$catalog.Close()}
