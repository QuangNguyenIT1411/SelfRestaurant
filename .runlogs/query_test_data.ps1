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

$result = [ordered]@{}
$result.CatalogIngredients = Query 'RESTAURANT_CATALOG' @"
SELECT IngredientID, Name, Unit, IsActive
FROM Ingredients
WHERE Name LIKE 'ING[_]UI[_]%'
   OR Name LIKE 'ING[_]RT[_]%'
   OR Name LIKE 'AUTO[_]%'
   OR Name LIKE 'DBG[_]%'
   OR Name LIKE 'CODEX[_]%'
   OR Name LIKE 'TEST%'
   OR Name LIKE 'TEMP%'
   OR Name LIKE 'DEMO%'
ORDER BY IngredientID;
"@
$result.CatalogDishes = Query 'RESTAURANT_CATALOG' @"
SELECT DishID, Name, CategoryID, ISNULL(IsActive,0) AS IsActive, ISNULL(Available,0) AS Available
FROM Dishes
WHERE Name LIKE 'AUTO[_]ADMIN[_]TEST%'
   OR Name LIKE 'AUTO[_]%'
   OR Name LIKE 'DBG[_]%'
   OR Name LIKE 'CODEX[_]%'
   OR Name LIKE 'TEST%'
   OR Name LIKE 'TEMP%'
   OR Name LIKE 'DEMO%'
ORDER BY DishID;
"@
$result.CatalogTables = Query 'RESTAURANT_CATALOG' @"
SELECT TableID, BranchID, QRCode, ISNULL(IsActive,0) AS IsActive, CurrentOrderID
FROM DiningTables
WHERE QRCode LIKE 'AUTO-%'
   OR QRCode LIKE '%TEST%'
   OR QRCode LIKE '%TEMP%'
   OR QRCode LIKE '%DEMO%'
ORDER BY TableID;
"@
$result.IdentityCustomers = Query 'RESTAURANT_IDENTITY' @"
SELECT CustomerID, Name, Username, PhoneNumber, Email, ISNULL(IsActive,0) AS IsActive
FROM Customers
WHERE Username LIKE 'autocus%'
   OR Username LIKE 'cusd[_]%'
   OR Username LIKE '%test%'
   OR Username LIKE '%demo%'
   OR Name LIKE 'AUTO%'
   OR Name LIKE 'TEST%'
   OR Name LIKE 'TEMP%'
   OR Name LIKE 'DEMO%'
   OR ISNULL(Email,'') LIKE '%@example.local'
ORDER BY CustomerID;
"@
$result.IdentityEmployees = Query 'RESTAURANT_IDENTITY' @"
SELECT EmployeeID, Name, Username, Email, ISNULL(IsActive,0) AS IsActive
FROM Employees
WHERE Username LIKE 'autoemp%'
   OR Username LIKE '%test%'
   OR Username LIKE '%demo%'
   OR Name LIKE 'Auto Employee%'
   OR Name LIKE 'TEST%'
   OR Name LIKE 'TEMP%'
   OR Name LIKE 'DEMO%'
ORDER BY EmployeeID;
"@
$result.OrdersOrders = Query 'RESTAURANT_ORDERS' @"
SELECT TOP 100 OrderID, OrderCode, Note, DiningSessionCode, CustomerID, TableID, StatusID, IsActive, OrderTime
FROM Orders
WHERE ISNULL(Note,'') LIKE 'qr-runtime%'
   OR ISNULL(Note,'') LIKE 'cash-runtime%'
   OR ISNULL(Note,'') LIKE '%test%'
   OR ISNULL(Note,'') LIKE '%demo%'
   OR ISNULL(OrderCode,'') LIKE 'ORD[_]RT[_]%'
ORDER BY OrderID DESC;
"@
$result.OrdersItems = Query 'RESTAURANT_ORDERS' @"
SELECT TOP 100 oi.ItemID, oi.OrderID, oi.Note, oi.DishID, oi.Quantity
FROM OrderItems oi
WHERE ISNULL(oi.Note,'') LIKE 'qr-runtime%'
   OR ISNULL(oi.Note,'') LIKE 'cash-runtime%'
   OR ISNULL(oi.Note,'') LIKE '%test%'
   OR ISNULL(oi.Note,'') LIKE '%demo%'
ORDER BY oi.ItemID DESC;
"@
$result.BillingBills = Query 'RESTAURANT_BILLING' @"
SELECT TOP 30 BillID, BillCode, OrderID, OrderCodeSnapshot, PaymentMethod, TotalAmount, BillTime
FROM Bills
ORDER BY BillID DESC;
"@
$result.BillingCheckout = Query 'RESTAURANT_BILLING' @"
SELECT TOP 30 CheckoutCommandId, OrderId, BillId, BillCode, Status, CreatedAtUtc, Error
FROM CheckoutCommands
ORDER BY CheckoutCommandId DESC;
"@

$result.GetEnumerator() | ForEach-Object {
  Write-Output ("=== " + $_.Key + " ===")
  if ($_.Value.Rows.Count -eq 0) { Write-Output '<none>'; return }
  $_.Value | Format-Table -AutoSize | Out-String -Width 240 | Write-Output
}
