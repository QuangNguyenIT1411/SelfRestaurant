$ErrorActionPreference = 'Stop'
function Query($db, $sql) {
  $conn = New-Object System.Data.SqlClient.SqlConnection("Server=(localdb)\MSSQLLocalDB;Database=$db;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=True")
  $conn.Open()
  try {
    $cmd = $conn.CreateCommand(); $cmd.CommandText = $sql; $cmd.CommandTimeout = 120
    $da = New-Object System.Data.SqlClient.SqlDataAdapter($cmd)
    $dt = New-Object System.Data.DataTable
    [void]$da.Fill($dt)
    return $dt
  } finally { $conn.Close() }
}

Write-Output '=== Catalog ingredient refs ==='
Query 'RESTAURANT_CATALOG' @"
SELECT i.IngredientID, i.Name,
       COUNT(DISTINCT di.DishIngredientID) AS DishIngredientRefs
FROM Ingredients i
LEFT JOIN DishIngredients di ON di.IngredientID = i.IngredientID
WHERE i.Name LIKE 'ING[_]UI[_]%'
   OR i.Name LIKE 'ING[_]RT[_]%'
   OR i.Name LIKE 'AUTO[_]%'
GROUP BY i.IngredientID, i.Name
ORDER BY i.IngredientID;
"@ | Format-Table -AutoSize | Out-String -Width 240 | Write-Output

Write-Output '=== Catalog dish refs ==='
Query 'RESTAURANT_CATALOG' @"
SELECT d.DishID, d.Name,
       COUNT(DISTINCT di.DishIngredientID) AS DishIngredientRefs,
       COUNT(DISTINCT CASE WHEN cd.DishID IS NOT NULL THEN CONCAT(cd.MenuCategoryID, '-', cd.DishID) END) AS MenuRefs,
       COUNT(DISTINCT oi.ItemID) AS OrderItemRefs
FROM Dishes d
LEFT JOIN DishIngredients di ON di.DishID = d.DishID
LEFT JOIN CategoryDish cd ON cd.DishID = d.DishID
LEFT JOIN OrderItems oi ON oi.DishID = d.DishID
WHERE d.Name LIKE 'AUTO[_]ADMIN[_]TEST%'
   OR d.Name LIKE 'AUTO[_]%'
GROUP BY d.DishID, d.Name
ORDER BY d.DishID;
"@ | Format-Table -AutoSize | Out-String -Width 240 | Write-Output

Write-Output '=== Catalog table refs ==='
Query 'RESTAURANT_CATALOG' @"
SELECT t.TableID, t.QRCode, COUNT(o.OrderID) AS OrderRefs
FROM DiningTables t
LEFT JOIN Orders o ON o.TableID = t.TableID
WHERE t.QRCode LIKE 'AUTO-%' OR t.QRCode LIKE '%TEST%'
GROUP BY t.TableID, t.QRCode
ORDER BY t.TableID;
"@ | Format-Table -AutoSize | Out-String -Width 240 | Write-Output

Write-Output '=== Identity customer refs in orders/bills ==='
Query 'RESTAURANT_IDENTITY' @"
SELECT c.CustomerID, c.Name, c.Username, c.Email
FROM Customers c
WHERE c.CustomerID IN (1231,2613,2620)
ORDER BY c.CustomerID;
"@ | Format-Table -AutoSize | Out-String -Width 240 | Write-Output
Query 'RESTAURANT_ORDERS' @"
SELECT OrderID, CustomerID, OrderCode, Note, StatusID
FROM Orders
WHERE CustomerID IN (1231,2613,2620)
ORDER BY OrderID;
"@ | Format-Table -AutoSize | Out-String -Width 240 | Write-Output
Query 'RESTAURANT_BILLING' @"
SELECT BillID, CustomerID, BillCode, OrderID, TotalAmount
FROM Bills
WHERE CustomerID IN (1231,2613,2620)
ORDER BY BillID;
"@ | Format-Table -AutoSize | Out-String -Width 240 | Write-Output

Write-Output '=== Recent orders/bills detail ==='
Query 'RESTAURANT_ORDERS' @"
SELECT o.OrderID, o.OrderCode, o.Note, o.CustomerID, o.TableID, o.StatusID, o.IsActive, o.OrderTime,
       COUNT(oi.ItemID) AS ItemCount,
       SUM(CASE WHEN oi.ItemID IS NULL THEN 0 ELSE oi.LineTotal END) AS ItemTotal
FROM Orders o
LEFT JOIN OrderItems oi ON oi.OrderID = o.OrderID
WHERE o.OrderID >= 285
GROUP BY o.OrderID, o.OrderCode, o.Note, o.CustomerID, o.TableID, o.StatusID, o.IsActive, o.OrderTime
ORDER BY o.OrderID;
"@ | Format-Table -AutoSize | Out-String -Width 240 | Write-Output
Query 'RESTAURANT_BILLING' @"
SELECT b.BillID, b.BillCode, b.OrderID, b.OrderCodeSnapshot, b.PaymentMethod, b.TotalAmount, b.CustomerID, b.BillTime,
       cc.CheckoutCommandId, cc.Status, cc.CompletedAtUtc
FROM Bills b
LEFT JOIN CheckoutCommands cc ON cc.BillId = b.BillID
WHERE b.BillID >= 135
ORDER BY b.BillID;
"@ | Format-Table -AutoSize | Out-String -Width 240 | Write-Output
