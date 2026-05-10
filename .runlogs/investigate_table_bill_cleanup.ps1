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
  $bills = Query $billing @"
SELECT b.BillID,b.OrderID,b.CustomerID,b.EmployeeID,b.BillStatus,b.PaymentMethod,b.TotalAmount,b.CreatedAt,
       o.OrderCode,o.TableID,o.Status AS OrderStatus,
       CASE WHEN o.OrderCode LIKE 'ORD_RT_%' OR o.OrderCode LIKE 'AUTO%' THEN 1 ELSE 0 END AS OrderLooksTest,
       CASE WHEN EXISTS (SELECT 1 FROM [RESTAURANT_ORDERS].dbo.OrderItems oi WHERE oi.OrderID=b.OrderID AND (
            ISNULL(oi.Note,'') LIKE '%rt-%' OR ISNULL(oi.Note,'') LIKE '%runtime%' OR ISNULL(oi.Note,'') LIKE '%AUTO%' OR ISNULL(oi.Note,'') LIKE '%TEST%')) THEN 1 ELSE 0 END AS ItemLooksTest,
       CASE WHEN EXISTS (SELECT 1 FROM CheckoutCommands cc WHERE cc.OrderId=b.OrderID AND ISNULL(cc.Status,'') <> 'COMPLETED') THEN 1 ELSE 0 END AS HasNonCompletedCheckout,
       (SELECT COUNT(*) FROM CheckoutCommands cc WHERE cc.OrderId=b.OrderID) AS CheckoutCount
FROM Bills b
LEFT JOIN [RESTAURANT_ORDERS].dbo.Orders o ON o.OrderID=b.OrderID
WHERE ISNULL(b.BillStatus,'') <> 'PAID'
   OR ISNULL(b.BillStatus,'') IN ('PENDING','FAILED','ABANDONED','UNPAID')
ORDER BY b.BillID;
"@
  [pscustomobject]@{
    suspiciousTables = @($tables | Select-Object TableID,BranchID,NumberOfSeats,QRCode,IsActive,StatusCode,CurrentOrderID,LooksTest,HasOrderHistory,OrderCount,HasBillHistory)
    unpaidBills = @($bills | Select-Object BillID,OrderID,BillStatus,PaymentMethod,TotalAmount,CreatedAt,OrderCode,TableID,OrderStatus,OrderLooksTest,ItemLooksTest,HasNonCompletedCheckout,CheckoutCount)
  } | ConvertTo-Json -Depth 6
}
finally { $catalog.Close(); $orders.Close(); $billing.Close() }
