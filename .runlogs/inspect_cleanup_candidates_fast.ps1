$ErrorActionPreference = "Stop"
function Conn($db){$c=New-Object System.Data.SqlClient.SqlConnection("Server=(localdb)\MSSQLLocalDB;Database=$db;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=True");$c.Open();$c}
function Query($conn,$sql){$cmd=$conn.CreateCommand();$cmd.CommandText=$sql;$cmd.CommandTimeout=120;$da=New-Object System.Data.SqlClient.SqlDataAdapter($cmd);$dt=New-Object System.Data.DataTable;[void]$da.Fill($dt);$dt}
$catalog=Conn "RESTAURANT_CATALOG"
$orders=Conn "RESTAURANT_ORDERS"
$billing=Conn "RESTAURANT_BILLING"
try {
  [pscustomobject]@{
    orders = @(
      Query $orders @"
SELECT o.OrderID,o.OrderCode,o.TableID,o.CustomerID,o.IsActive,o.OrderTime,o.CompletedTime,os.StatusCode
FROM Orders o
JOIN OrderStatus os ON os.StatusID=o.StatusID
WHERE o.OrderID IN (296,297,298,299,301,302,303)
ORDER BY o.OrderID;
"@
    )
    orderItems = @(
      Query $orders @"
SELECT ItemID,OrderID,DishID,Quantity,Note,StatusCode
FROM OrderItems
WHERE OrderID IN (296,297,298,299,301,302,303)
ORDER BY OrderID,ItemID;
"@
    )
    bills = @(
      Query $billing @"
SELECT BillID,OrderID,BillCode,IsActive,TotalAmount,PaymentMethod,BillTime
FROM Bills
WHERE OrderID IN (296,297,298,299,301,302,303)
ORDER BY BillID;
"@
    )
    checkout = @(
      Query $billing @"
SELECT CheckoutCommandId,OrderId,BillId,BillCode,Status,CreatedAtUtc,CompletedAtUtc,Error
FROM CheckoutCommands
WHERE OrderId IN (296,297,298,299,301,302,303) OR BillId IN (SELECT BillID FROM Bills WHERE OrderID IN (296,297,298,299,301,302,303))
ORDER BY CheckoutCommandId;
"@
    )
    ghostTables = @(
      Query $catalog @"
SELECT t.TableID,t.BranchID,t.TableNumber,t.QRCode,ts.StatusCode,t.CurrentOrderID
FROM DiningTables t
JOIN TableStatus ts ON ts.StatusID=t.StatusID
WHERE t.TableID IN (21,22,23,24,6,38)
ORDER BY t.TableID;
"@
    )
  } | ConvertTo-Json -Depth 8
}
finally {$catalog.Close();$orders.Close();$billing.Close()}
