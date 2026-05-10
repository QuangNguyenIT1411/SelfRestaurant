$ErrorActionPreference='Stop'
function Conn($db){$c=New-Object System.Data.SqlClient.SqlConnection("Server=(localdb)\MSSQLLocalDB;Database=$db;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=True");$c.Open();$c}
function Query($conn,$sql){$cmd=$conn.CreateCommand();$cmd.CommandText=$sql;$cmd.CommandTimeout=120;$da=New-Object System.Data.SqlClient.SqlDataAdapter($cmd);$dt=New-Object System.Data.DataTable;[void]$da.Fill($dt);$dt}
$catalog=Conn 'RESTAURANT_CATALOG'
try {
  $dt = Query $catalog @"
SELECT t.TableID,t.BranchID,t.NumberOfSeats,t.QRCode,ISNULL(t.IsActive,1) AS IsActive,ts.StatusCode,t.CurrentOrderID,
       o.OrderCode,os.StatusCode AS OrderStatusCode,ISNULL(o.IsActive,0) AS OrderIsActive,
       CASE WHEN t.CurrentOrderID IS NOT NULL AND o.OrderID IS NULL THEN 1 ELSE 0 END AS MissingOrder,
       CASE WHEN t.CurrentOrderID IS NOT NULL AND o.OrderID IS NOT NULL AND (ISNULL(o.IsActive,0)=0 OR os.StatusCode IN ('COMPLETED','CANCELLED')) THEN 1 ELSE 0 END AS StaleOrderRef,
       CASE WHEN EXISTS (SELECT 1 FROM [RESTAURANT_BILLING].dbo.Bills b WHERE b.OrderID=t.CurrentOrderID AND b.IsActive=1) THEN 1 ELSE 0 END AS HasActiveBill
FROM DiningTables t
LEFT JOIN TableStatus ts ON ts.StatusID=t.StatusID
LEFT JOIN [RESTAURANT_ORDERS].dbo.Orders o ON o.OrderID=t.CurrentOrderID
LEFT JOIN [RESTAURANT_ORDERS].dbo.OrderStatus os ON os.StatusID=o.StatusID
WHERE ISNULL(t.IsActive,1)=1
  AND (ts.StatusCode='OCCUPIED' OR t.CurrentOrderID IS NOT NULL)
ORDER BY t.BranchID,t.TableID;
"@
  $dt | Select-Object TableID,BranchID,NumberOfSeats,QRCode,StatusCode,CurrentOrderID,OrderCode,OrderStatusCode,OrderIsActive,MissingOrder,StaleOrderRef,HasActiveBill | ConvertTo-Json -Depth 5
}
finally {$catalog.Close()}
