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

Write-Output '=== Catalog dish refs ==='
Query 'RESTAURANT_CATALOG' @"
SELECT d.DishID, d.Name,
       COUNT(DISTINCT di.DishIngredientID) AS DishIngredientRefs,
       COUNT(DISTINCT CASE WHEN cd.DishID IS NOT NULL THEN CONCAT(cd.MenuCategoryID, '-', cd.DishID) END) AS MenuRefs
FROM Dishes d
LEFT JOIN DishIngredients di ON di.DishID = d.DishID
LEFT JOIN CategoryDish cd ON cd.DishID = d.DishID
WHERE d.Name LIKE 'AUTO[_]ADMIN[_]TEST%'
   OR d.Name LIKE 'AUTO[_]%'
GROUP BY d.DishID, d.Name
ORDER BY d.DishID;
"@ | Format-Table -AutoSize | Out-String -Width 240 | Write-Output

Write-Output '=== Orders refs to test dishes ==='
Query 'RESTAURANT_ORDERS' @"
SELECT oi.DishID, COUNT(*) AS OrderItemRefs
FROM OrderItems oi
WHERE oi.DishID IN (
    1103,1104,1105,1106,1107,1108,1109,1110,1111,1112,2127,2128,2129,2130,2131,2132,2133,2134,2135,2136,2137,2138,2139,2140,2141,3144,3149,3153,3154
)
GROUP BY oi.DishID
ORDER BY oi.DishID;
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
