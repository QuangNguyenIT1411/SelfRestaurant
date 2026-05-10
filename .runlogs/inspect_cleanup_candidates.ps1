$ErrorActionPreference = "Stop"

function Conn($db) {
  $c = New-Object System.Data.SqlClient.SqlConnection("Server=(localdb)\MSSQLLocalDB;Database=$db;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=True")
  $c.Open()
  return $c
}

function Query($conn, $sql) {
  $cmd = $conn.CreateCommand()
  $cmd.CommandText = $sql
  $cmd.CommandTimeout = 120
  $da = New-Object System.Data.SqlClient.SqlDataAdapter($cmd)
  $dt = New-Object System.Data.DataTable
  [void]$da.Fill($dt)
  return $dt
}

$catalog = Conn "RESTAURANT_CATALOG"
$orders = Conn "RESTAURANT_ORDERS"
$billing = Conn "RESTAURANT_BILLING"

try {
  $out = [ordered]@{}

  $out.ingredients = @(
    Query $catalog @"
SELECT
  i.IngredientID,
  i.Name,
  i.IsActive,
  DishRefs = (SELECT COUNT(*) FROM DishIngredients di WHERE di.IngredientID = i.IngredientID),
  AuditRefs = (SELECT COUNT(*) FROM BusinessAuditLogs b WHERE b.EntityType = 'INGREDIENT' AND TRY_CONVERT(int, b.EntityId) = i.IngredientID)
FROM Ingredients i
WHERE i.IngredientID IN (54, 61, 69)
ORDER BY i.IngredientID;
"@
  )

  $out.orders = @(
    Query $orders @"
SELECT
  o.OrderID,
  o.OrderCode,
  o.TableID,
  o.CustomerID,
  o.IsActive,
  o.OrderTime,
  o.CompletedTime,
  os.StatusCode,
  BillCount = (SELECT COUNT(*) FROM [RESTAURANT_BILLING].dbo.Bills b WHERE b.OrderID = o.OrderID),
  CheckoutCount = (SELECT COUNT(*) FROM [RESTAURANT_BILLING].dbo.CheckoutCommands c WHERE c.OrderId = o.OrderID),
  AuditCount = (SELECT COUNT(*) FROM BusinessAuditLogs a WHERE a.OrderId = o.OrderID),
  SubmitCount = (SELECT COUNT(*) FROM SubmitCommands s WHERE s.OrderId = o.OrderID),
  OutboxCount = (SELECT COUNT(*) FROM OutboxEvents e WHERE e.PayloadJson LIKE '%"orderId":' + CONVERT(varchar(20), o.OrderID) + '%')
FROM Orders o
JOIN OrderStatus os ON os.StatusID = o.StatusID
WHERE o.OrderID IN (296, 297, 298, 299, 301, 302, 303)
ORDER BY o.OrderID;
"@
  )

  $out.orderItems = @(
    Query $orders @"
SELECT
  oi.ItemID,
  oi.OrderID,
  oi.DishID,
  oi.Quantity,
  oi.Note,
  oi.StatusCode
FROM OrderItems oi
WHERE oi.OrderID IN (296, 297, 298, 299, 301, 302, 303)
ORDER BY oi.OrderID, oi.ItemID;
"@
  )

  $out.bills = @(
    Query $billing @"
SELECT
  b.BillID,
  b.OrderID,
  b.BillCode,
  b.IsActive,
  b.TotalAmount,
  b.PaymentMethod,
  b.BillTime,
  AuditCount = (SELECT COUNT(*) FROM BusinessAuditLogs a WHERE a.BillId = b.BillID),
  SnapshotCount = (SELECT COUNT(*) FROM OrderContextSnapshots s WHERE s.OrderId = b.OrderID),
  CheckoutCount = (SELECT COUNT(*) FROM CheckoutCommands c WHERE c.BillId = b.BillID OR c.OrderId = b.OrderID)
FROM Bills b
WHERE b.OrderID IN (296, 297, 298, 299, 301, 302, 303)
ORDER BY b.BillID;
"@
  )

  $out.catalogTables = @(
    Query $catalog @"
SELECT
  t.TableID,
  t.BranchID,
  t.TableNumber,
  t.QRCode,
  ts.StatusCode,
  t.CurrentOrderID,
  OrderRefCount = (SELECT COUNT(*) FROM [RESTAURANT_ORDERS].dbo.Orders o WHERE o.TableID = t.TableID)
FROM DiningTables t
JOIN TableStatus ts ON ts.StatusID = t.StatusID
WHERE t.TableID IN (6, 21, 22, 23, 24, 38)
ORDER BY t.TableID;
"@
  )

  $out | ConvertTo-Json -Depth 8
}
finally {
  $catalog.Close()
  $orders.Close()
  $billing.Close()
}
