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
  $dishes = Query $catalog @"
SELECT
  d.DishID,
  d.Name,
  d.IsActive,
  d.Available,
  d.Image,
  CategoryLinks = (SELECT COUNT(*) FROM CategoryDish cd WHERE cd.DishID = d.DishID),
  OrderItemRefs = (SELECT COUNT(*) FROM [RESTAURANT_ORDERS].dbo.OrderItems oi WHERE oi.DishID = d.DishID),
  Reason = CASE
    WHEN UPPER(d.Name) LIKE '%TEST%' THEN 'name contains TEST'
    WHEN UPPER(d.Name) LIKE 'AUTO%' THEN 'name starts with AUTO'
    WHEN UPPER(d.Name) LIKE '%CODEX%' THEN 'name contains CODEX'
    WHEN UPPER(d.Name) LIKE '%DEBUG%' THEN 'name contains DEBUG'
    WHEN d.Name LIKE 'DbgUpload%' THEN 'debug upload artifact'
    WHEN d.Name LIKE 'UploadDish%' THEN 'upload artifact'
    WHEN d.Name LIKE 'DEL[_]RT[_]%' THEN 'runtime delete test dish'
    WHEN d.Name LIKE 'DEL[_]SQL[_]%' THEN 'sql delete test dish'
    WHEN d.Name LIKE 'AUTO[_]ADMIN[_]TEST%' THEN 'admin runtime test dish'
    WHEN d.Name LIKE 'AUTO[_]CHEF[_]%' THEN 'chef runtime test dish'
    WHEN d.Name LIKE 'AUTO[_]DISH%' THEN 'runtime test dish'
    ELSE NULL
  END
FROM Dishes d
WHERE
  UPPER(d.Name) LIKE '%TEST%'
  OR UPPER(d.Name) LIKE 'AUTO%'
  OR UPPER(d.Name) LIKE '%CODEX%'
  OR UPPER(d.Name) LIKE '%DEBUG%'
  OR d.Name LIKE 'DbgUpload%'
  OR d.Name LIKE 'UploadDish%'
  OR d.Name LIKE 'DEL[_]RT[_]%'
  OR d.Name LIKE 'DEL[_]SQL[_]%'
ORDER BY d.DishID;
"@

  $ingredients = Query $catalog @"
SELECT
  i.IngredientID,
  i.Name,
  i.IsActive,
  DishRefs = (SELECT COUNT(*) FROM DishIngredients di WHERE di.IngredientID = i.IngredientID),
  Reason = CASE
    WHEN UPPER(i.Name) LIKE '%TEST%' THEN 'name contains TEST'
    WHEN UPPER(i.Name) LIKE 'AUTO%' THEN 'name starts with AUTO'
    WHEN UPPER(i.Name) LIKE '%CODEX%' THEN 'name contains CODEX'
    WHEN UPPER(i.Name) LIKE '%DEBUG%' THEN 'name contains DEBUG'
    WHEN i.Name LIKE 'ING[_]RT[_]%' THEN 'runtime ingredient'
    WHEN i.Name LIKE 'ING[_]UI[_]%' THEN 'ui verification ingredient'
    WHEN i.Name LIKE 'AUTO[_]ING%' THEN 'auto ingredient'
    ELSE NULL
  END
FROM Ingredients i
WHERE
  UPPER(i.Name) LIKE '%TEST%'
  OR UPPER(i.Name) LIKE 'AUTO%'
  OR UPPER(i.Name) LIKE '%CODEX%'
  OR UPPER(i.Name) LIKE '%DEBUG%'
  OR i.Name LIKE 'ING[_]RT[_]%'
  OR i.Name LIKE 'ING[_]UI[_]%'
  OR i.Name LIKE 'AUTO[_]ING%'
ORDER BY i.IngredientID;
"@

  $tables = Query $catalog @"
SELECT
  t.TableID,
  t.BranchID,
  t.TableNumber,
  t.QRCode,
  ts.StatusCode,
  t.CurrentOrderID,
  OrderRefs = (SELECT COUNT(*) FROM [RESTAURANT_ORDERS].dbo.Orders o WHERE o.TableID = t.TableID),
  Reason = CASE
    WHEN t.QRCode LIKE 'AUTO-%' THEN 'QR code AUTO-*'
    WHEN UPPER(ISNULL(t.QRCode,'')) LIKE 'CODEX-TB-TEST%' THEN 'QR code CODEX-TB-TEST*'
    WHEN UPPER(ISNULL(t.QRCode,'')) LIKE '%TEST%' THEN 'QR code contains TEST'
    ELSE NULL
  END
FROM DiningTables t
LEFT JOIN TableStatus ts ON ts.StatusID = t.StatusID
WHERE
  t.QRCode LIKE 'AUTO-%'
  OR UPPER(ISNULL(t.QRCode,'')) LIKE 'CODEX-TB-TEST%'
  OR UPPER(ISNULL(t.QRCode,'')) LIKE '%TEST%'
ORDER BY t.TableID;
"@

  $ghostTables = Query $catalog @"
SELECT
  t.TableID,
  t.BranchID,
  t.TableNumber,
  t.QRCode,
  ts.StatusCode,
  t.CurrentOrderID
FROM DiningTables t
JOIN TableStatus ts ON ts.StatusID = t.StatusID
WHERE ISNULL(t.IsActive,1)=1
  AND ts.StatusCode='OCCUPIED'
  AND t.CurrentOrderID IS NULL
  AND NOT EXISTS (
    SELECT 1
    FROM [RESTAURANT_ORDERS].dbo.Orders o
    JOIN [RESTAURANT_ORDERS].dbo.OrderStatus os ON os.StatusID = o.StatusID
    WHERE o.TableID = t.TableID
      AND ISNULL(o.IsActive,0)=1
      AND os.StatusCode IN ('PENDING','CONFIRMED','PREPARING','READY','SERVING')
  )
ORDER BY t.BranchID, t.TableNumber, t.TableID;
"@

  $ordersPreview = Query $orders @"
SELECT TOP 50
  o.OrderID,
  o.OrderCode,
  o.TableID,
  os.StatusCode,
  o.IsActive,
  o.OrderTime,
  o.CompletedTime,
  ItemCount = COUNT(oi.ItemID),
  HasReadyAckVerify = MAX(CASE WHEN oi.Note LIKE 'READY_ACK_VERIFY%' THEN 1 ELSE 0 END),
  HasQrRuntime = MAX(CASE WHEN oi.Note LIKE '%qr-runtime%' THEN 1 ELSE 0 END),
  HasCashRuntime = MAX(CASE WHEN oi.Note LIKE '%cash-runtime%' THEN 1 ELSE 0 END),
  HasTestNote = MAX(CASE WHEN oi.Note LIKE '%TEST%' THEN 1 ELSE 0 END),
  HasDebugNote = MAX(CASE WHEN oi.Note LIKE '%DEBUG%' THEN 1 ELSE 0 END),
  Reason = CASE
    WHEN MAX(CASE WHEN oi.Note LIKE 'READY_ACK_VERIFY%' THEN 1 ELSE 0 END) = 1 THEN 'ready ack verification order'
    WHEN MAX(CASE WHEN oi.Note LIKE '%qr-runtime%' THEN 1 ELSE 0 END) = 1 THEN 'qr runtime verification order'
    WHEN MAX(CASE WHEN oi.Note LIKE '%cash-runtime%' THEN 1 ELSE 0 END) = 1 THEN 'cash runtime verification order'
    WHEN MAX(CASE WHEN oi.Note LIKE '%TEST%' THEN 1 ELSE 0 END) = 1 THEN 'item note contains TEST'
    WHEN MAX(CASE WHEN oi.Note LIKE '%DEBUG%' THEN 1 ELSE 0 END) = 1 THEN 'item note contains DEBUG'
    WHEN o.OrderCode LIKE 'TEST%' THEN 'order code starts with TEST'
    ELSE NULL
  END
FROM Orders o
JOIN OrderStatus os ON os.StatusID = o.StatusID
LEFT JOIN OrderItems oi ON oi.OrderID = o.OrderID
GROUP BY o.OrderID, o.OrderCode, o.TableID, os.StatusCode, o.IsActive, o.OrderTime, o.CompletedTime
HAVING
  MAX(CASE WHEN oi.Note LIKE 'READY_ACK_VERIFY%' THEN 1 ELSE 0 END) = 1
  OR MAX(CASE WHEN oi.Note LIKE '%qr-runtime%' THEN 1 ELSE 0 END) = 1
  OR MAX(CASE WHEN oi.Note LIKE '%cash-runtime%' THEN 1 ELSE 0 END) = 1
  OR MAX(CASE WHEN oi.Note LIKE '%TEST%' THEN 1 ELSE 0 END) = 1
  OR MAX(CASE WHEN oi.Note LIKE '%DEBUG%' THEN 1 ELSE 0 END) = 1
  OR o.OrderCode LIKE 'TEST%'
  OR (os.StatusCode IN ('PENDING','CONFIRMED') AND o.OrderTime < DATEADD(day, -1, GETDATE()) AND ISNULL(o.IsActive,1)=1)
ORDER BY o.OrderID DESC;
"@

  $checkoutCommands = Query $billing @"
SELECT
  CheckoutCommandId,
  OrderId,
  BillId,
  BillCode,
  Status,
  CreatedAtUtc,
  CompletedAtUtc,
  Error
FROM CheckoutCommands
WHERE Status <> 'COMPLETED'
ORDER BY CheckoutCommandId;
"@

  $inactiveBills = Query $billing @"
SELECT
  BillID,
  OrderID,
  BillCode,
  IsActive,
  BillTime,
  TotalAmount,
  PaymentMethod
FROM Bills
WHERE ISNULL(IsActive,1) = 0
ORDER BY BillID;
"@

  $billingAudit = Query $billing @"
SELECT TOP 20 BusinessAuditLogId, ActionType, EntityType, EntityId, OrderId, BillId, Notes, CreatedAtUtc
FROM BusinessAuditLogs
ORDER BY BusinessAuditLogId DESC;
"@

  [pscustomobject]@{
    dishes = @($dishes | Select-Object DishID,Name,IsActive,Available,CategoryLinks,OrderItemRefs,Reason)
    ingredients = @($ingredients | Select-Object IngredientID,Name,IsActive,DishRefs,Reason)
    testTables = @($tables | Select-Object TableID,BranchID,TableNumber,QRCode,StatusCode,CurrentOrderID,OrderRefs,Reason)
    ghostTables = @($ghostTables | Select-Object TableID,BranchID,TableNumber,QRCode,StatusCode,CurrentOrderID)
    unfinishedOrders = @($ordersPreview | Select-Object OrderID,OrderCode,TableID,StatusCode,IsActive,OrderTime,CompletedTime,ItemCount,HasReadyAckVerify,HasQrRuntime,HasCashRuntime,HasTestNote,HasDebugNote,Reason)
    checkoutCommands = @($checkoutCommands | Select-Object CheckoutCommandId,OrderId,BillId,BillCode,Status,CreatedAtUtc,CompletedAtUtc,Error)
    inactiveBills = @($inactiveBills | Select-Object BillID,OrderID,BillCode,IsActive,BillTime,TotalAmount,PaymentMethod)
    billingAuditTail = @($billingAudit | Select-Object -First 5)
  } | ConvertTo-Json -Depth 8
}
finally {
  $catalog.Close()
  $orders.Close()
  $billing.Close()
}
