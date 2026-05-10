$ErrorActionPreference = "Stop"

function Conn($db) {
  $c = New-Object System.Data.SqlClient.SqlConnection("Server=(localdb)\MSSQLLocalDB;Database=$db;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=True")
  $c.Open()
  return $c
}

function NonQuery($conn, $tx, $sql) {
  $cmd = $conn.CreateCommand()
  if ($null -ne $tx) {
    $cmd.Transaction = $tx
  }
  $cmd.CommandText = $sql
  $cmd.CommandTimeout = 120
  [void]$cmd.ExecuteNonQuery()
}

function Scalar($conn, $sql) {
  $cmd = $conn.CreateCommand()
  $cmd.CommandText = $sql
  $cmd.CommandTimeout = 120
  return $cmd.ExecuteScalar()
}

$catalog = Conn "RESTAURANT_CATALOG"
$orders = Conn "RESTAURANT_ORDERS"
$billing = Conn "RESTAURANT_BILLING"

try {
  $ingredientIds = "54,61,69"
  $testOrderIds = "296,297,298,299,301,302"
  $abandonedOrderIds = "303"
  $allOrderIds = "$testOrderIds,$abandonedOrderIds"
  $billIds = "138"
  $releaseTableIds = "6,21,22,23,24,38"

  $precheck = [ordered]@{
    ingredientCount = [int](Scalar $catalog "SELECT COUNT(*) FROM Ingredients WHERE IngredientID IN ($ingredientIds);")
    testOrderCount = [int](Scalar $orders "SELECT COUNT(*) FROM Orders WHERE OrderID IN ($testOrderIds);")
    abandonedOrderCount = [int](Scalar $orders "SELECT COUNT(*) FROM Orders WHERE OrderID IN ($abandonedOrderIds);")
    billCount = [int](Scalar $billing "SELECT COUNT(*) FROM Bills WHERE BillID IN ($billIds);")
    ghostTableCount = [int](Scalar $catalog @"
SELECT COUNT(*)
FROM DiningTables t
JOIN TableStatus ts ON ts.StatusID=t.StatusID
WHERE t.TableID IN (21,22,23,24)
  AND ts.StatusCode='OCCUPIED'
  AND t.CurrentOrderID IS NULL;
"@)
  }

  $catalogTx = $catalog.BeginTransaction()
  $ordersTx = $orders.BeginTransaction()
  $billingTx = $billing.BeginTransaction()

  try {
    NonQuery $catalog $catalogTx @"
DELETE FROM BusinessAuditLogs
WHERE EntityType='INGREDIENT'
  AND TRY_CONVERT(int, EntityId) IN ($ingredientIds);

DELETE FROM DishIngredients
WHERE IngredientID IN ($ingredientIds);

DELETE FROM Ingredients
WHERE IngredientID IN ($ingredientIds);
"@

    NonQuery $billing $billingTx @"
DELETE FROM BusinessAuditLogs
WHERE OrderId IN ($allOrderIds)
   OR BillId IN ($billIds);

DELETE FROM OutboxEvents
WHERE PayloadJson LIKE '%"orderId":296%'
   OR PayloadJson LIKE '%"orderId":297%'
   OR PayloadJson LIKE '%"orderId":298%'
   OR PayloadJson LIKE '%"orderId":299%'
   OR PayloadJson LIKE '%"orderId":301%'
   OR PayloadJson LIKE '%"orderId":302%'
   OR PayloadJson LIKE '%"orderId":303%'
   OR PayloadJson LIKE '%"billId":138%';

DELETE FROM OrderContextSnapshots
WHERE OrderId IN ($allOrderIds);

DELETE FROM CheckoutCommands
WHERE OrderId IN ($allOrderIds)
   OR BillId IN ($billIds);

DELETE FROM Bills
WHERE BillID IN ($billIds)
   OR OrderID IN ($allOrderIds);
"@

    NonQuery $orders $ordersTx @"
DELETE FROM BusinessAuditLogs
WHERE OrderId IN ($allOrderIds);

DELETE FROM SubmitCommands
WHERE OrderId IN ($allOrderIds);

DELETE FROM OutboxEvents
WHERE PayloadJson LIKE '%"orderId":296%'
   OR PayloadJson LIKE '%"orderId":297%'
   OR PayloadJson LIKE '%"orderId":298%'
   OR PayloadJson LIKE '%"orderId":299%'
   OR PayloadJson LIKE '%"orderId":301%'
   OR PayloadJson LIKE '%"orderId":302%'
   OR PayloadJson LIKE '%"orderId":303%';

DELETE FROM OrderItems
WHERE OrderID IN ($allOrderIds);

DELETE FROM Orders
WHERE OrderID IN ($allOrderIds);
"@

    NonQuery $catalog $catalogTx @"
DECLARE @availableStatusId int = (SELECT TOP 1 StatusID FROM TableStatus WHERE StatusCode='AVAILABLE');

UPDATE DiningTables
SET CurrentOrderID = NULL,
    StatusID = @availableStatusId,
    UpdatedAt = GETDATE()
WHERE TableID IN ($releaseTableIds);
"@

    $billingTx.Commit()
    $ordersTx.Commit()
    $catalogTx.Commit()
  }
  catch {
    $billingTx.Rollback()
    $ordersTx.Rollback()
    $catalogTx.Rollback()
    throw
  }

  [pscustomobject]@{
    precheck = $precheck
    remainingIngredients = [int](Scalar $catalog "SELECT COUNT(*) FROM Ingredients WHERE IngredientID IN ($ingredientIds);")
    remainingOrders = [int](Scalar $orders "SELECT COUNT(*) FROM Orders WHERE OrderID IN ($allOrderIds);")
    remainingBills = [int](Scalar $billing "SELECT COUNT(*) FROM Bills WHERE BillID IN ($billIds) OR OrderID IN ($allOrderIds);")
    remainingGhostTables = [int](Scalar $catalog @"
SELECT COUNT(*)
FROM DiningTables t
JOIN TableStatus ts ON ts.StatusID=t.StatusID
WHERE t.TableID IN ($releaseTableIds)
  AND ts.StatusCode='OCCUPIED';
"@)
  } | ConvertTo-Json -Depth 5
}
finally {
  $catalog.Close()
  $orders.Close()
  $billing.Close()
}
