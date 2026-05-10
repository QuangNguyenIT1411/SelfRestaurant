$ErrorActionPreference='Stop'
function Conn($db){$c=New-Object System.Data.SqlClient.SqlConnection("Server=(localdb)\MSSQLLocalDB;Database=$db;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=True");$c.Open();$c}
function Query($conn,$sql){$cmd=$conn.CreateCommand();$cmd.CommandText=$sql;$cmd.CommandTimeout=120;$da=New-Object System.Data.SqlClient.SqlDataAdapter($cmd);$dt=New-Object System.Data.DataTable;[void]$da.Fill($dt);$dt}
$catalog=Conn 'RESTAURANT_CATALOG'
$orders=Conn 'RESTAURANT_ORDERS'
$billing=Conn 'RESTAURANT_BILLING'
try {
  $tables = Query $catalog @"
SELECT t.TableID, t.BranchID, t.NumberOfSeats, t.QRCode, ISNULL(t.IsActive,1) AS IsActive,
       ts.StatusCode, t.CurrentOrderID,
       CASE WHEN t.QRCode LIKE 'AUTO-%' OR UPPER(ISNULL(t.QRCode,'')) LIKE 'CODEX-TB-TEST%' OR UPPER(ISNULL(t.QRCode,'')) LIKE '%TEST%' THEN 1 ELSE 0 END AS LooksTest,
       CASE WHEN EXISTS (SELECT 1 FROM [RESTAURANT_ORDERS].dbo.Orders o WHERE o.TableID = t.TableID) THEN 1 ELSE 0 END AS HasOrderHistory,
       (SELECT COUNT(*) FROM [RESTAURANT_ORDERS].dbo.Orders o WHERE o.TableID = t.TableID) AS OrderCount,
       CASE WHEN EXISTS (SELECT 1 FROM [RESTAURANT_BILLING].dbo.Bills b INNER JOIN [RESTAURANT_ORDERS].dbo.Orders o ON o.OrderID=b.OrderID WHERE o.TableID=t.TableID) THEN 1 ELSE 0 END AS HasBillHistory
FROM DiningTables t
LEFT JOIN TableStatus ts ON ts.StatusID=t.StatusID
WHERE t.QRCode LIKE 'AUTO-%'
   OR UPPER(ISNULL(t.QRCode,'')) LIKE 'CODEX-TB-TEST%'
   OR UPPER(ISNULL(t.QRCode,'')) LIKE '%TEST%'
ORDER BY t.TableID;
"@
  $inactiveBills = Query $billing @"
SELECT b.BillID,b.OrderID,b.BillCode,b.BillTime,b.TotalAmount,b.PaymentMethod,b.IsActive,
       b.OrderCodeSnapshot,b.TableIdSnapshot,b.BranchIdSnapshot
FROM Bills b
WHERE ISNULL(b.IsActive,1)=0
ORDER BY b.BillID;
"@
  $nonCompleted = Query $billing @"
SELECT cc.CheckoutCommandId,cc.OrderId,cc.BillId,cc.BillCode,cc.TotalAmount,cc.Status,cc.CreatedAtUtc,cc.CompletedAtUtc,cc.Error,
       o.OrderCode,o.TableID,os.StatusCode AS OrderStatusCode,
       CASE WHEN ISNULL(o.OrderCode,'') LIKE 'ORD_RT_%' OR ISNULL(o.OrderCode,'') LIKE 'AUTO%' THEN 1 ELSE 0 END AS OrderLooksTest,
       CASE WHEN EXISTS (SELECT 1 FROM [RESTAURANT_ORDERS].dbo.OrderItems oi WHERE oi.OrderID=cc.OrderId AND (
           ISNULL(oi.Note,'') LIKE '%rt-%' OR ISNULL(oi.Note,'') LIKE '%runtime%' OR ISNULL(oi.Note,'') LIKE '%AUTO%' OR ISNULL(oi.Note,'') LIKE '%TEST%')) THEN 1 ELSE 0 END AS ItemLooksTest
FROM CheckoutCommands cc
LEFT JOIN [RESTAURANT_ORDERS].dbo.Orders o ON o.OrderID=cc.OrderId
LEFT JOIN [RESTAURANT_ORDERS].dbo.OrderStatus os ON os.StatusID=o.StatusID
WHERE cc.Status <> 'COMPLETED'
ORDER BY cc.CheckoutCommandId;
"@
  [pscustomobject]@{
    suspiciousTables = @($tables | Select-Object TableID,BranchID,NumberOfSeats,QRCode,IsActive,StatusCode,CurrentOrderID,LooksTest,HasOrderHistory,OrderCount,HasBillHistory)
    inactiveBills = @($inactiveBills | Select-Object BillID,OrderID,BillCode,BillTime,TotalAmount,PaymentMethod,IsActive,OrderCodeSnapshot,TableIdSnapshot,BranchIdSnapshot)
    nonCompletedCheckoutCommands = @($nonCompleted | Select-Object CheckoutCommandId,OrderId,BillId,BillCode,TotalAmount,Status,CreatedAtUtc,CompletedAtUtc,Error,OrderCode,TableID,OrderStatusCode,OrderLooksTest,ItemLooksTest)
  } | ConvertTo-Json -Depth 6
}
finally { $catalog.Close(); $orders.Close(); $billing.Close() }
