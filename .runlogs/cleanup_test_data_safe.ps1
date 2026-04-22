param(
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

function New-Connection([string]$Database) {
    return New-Object System.Data.SqlClient.SqlConnection("Server=(localdb)\MSSQLLocalDB;Database=$Database;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=True")
}

function Invoke-NonQuery {
    param(
        [Parameter(Mandatory = $true)]
        [System.Data.SqlClient.SqlConnection]$Connection,
        [System.Data.SqlClient.SqlTransaction]$Transaction,
        [Parameter(Mandatory = $true)]
        [string]$Sql
    )

    $cmd = $Connection.CreateCommand()
    if ($null -ne $Transaction) {
        $cmd.Transaction = $Transaction
    }
    $cmd.CommandText = $Sql
    $cmd.CommandTimeout = 120
    return $cmd.ExecuteNonQuery()
}

function Invoke-Scalar {
    param(
        [Parameter(Mandatory = $true)]
        [System.Data.SqlClient.SqlConnection]$Connection,
        [Parameter(Mandatory = $true)]
        [string]$Sql
    )

    $cmd = $Connection.CreateCommand()
    $cmd.CommandText = $Sql
    $cmd.CommandTimeout = 120
    return $cmd.ExecuteScalar()
}

function Write-Section([string]$Title) {
    Write-Host ""
    Write-Host "=== $Title ==="
}

$testOrderIds = "287,288,289,290,291"
$testBillIds = "137"

$catalog = New-Connection "RESTAURANT_CATALOG"
$identity = New-Connection "RESTAURANT_IDENTITY"
$orders = New-Connection "RESTAURANT_ORDERS"
$billing = New-Connection "RESTAURANT_BILLING"

$catalog.Open()
$identity.Open()
$orders.Open()
$billing.Open()

try {
    Write-Section "Precheck"
    $catalogIngredientCount = [int](Invoke-Scalar -Connection $catalog -Sql @"
SELECT COUNT(*)
FROM Ingredients
WHERE Name LIKE 'ING[_]UI[_]%'
   OR Name LIKE 'ING[_]RT[_]%'
   OR Name LIKE 'AUTO[_]ING%'
"@)
    $catalogDishCount = [int](Invoke-Scalar -Connection $catalog -Sql @"
SELECT COUNT(*)
FROM Dishes
WHERE Name LIKE 'AUTO[_]ADMIN[_]TEST%'
   OR Name LIKE 'AUTO[_]CHEF[_]%'
   OR Name LIKE 'AUTO[_]DISH%'
"@)
    $catalogTableCount = [int](Invoke-Scalar -Connection $catalog -Sql @"
SELECT COUNT(*)
FROM DiningTables
WHERE QRCode LIKE 'AUTO-%'
   OR UPPER(ISNULL(QRCode, '')) LIKE 'CODEX-TB-TEST%'
"@)
    $identityCustomerCount = [int](Invoke-Scalar -Connection $identity -Sql @"
SELECT COUNT(*)
FROM Customers c
WHERE (
        c.Username LIKE 'autocus%'
        OR c.Username LIKE 'cusd[_]%'
        OR c.Username IN ('test123', 'test', 'testquang')
        OR c.Name LIKE 'test%'
     )
  AND NOT EXISTS (SELECT 1 FROM [RESTAURANT_ORDERS].dbo.Orders o WHERE o.CustomerID = c.CustomerID)
  AND NOT EXISTS (SELECT 1 FROM [RESTAURANT_BILLING].dbo.Bills b WHERE b.CustomerID = c.CustomerID)
"@)
    $orderCount = [int](Invoke-Scalar -Connection $orders -Sql "SELECT COUNT(*) FROM Orders WHERE OrderID IN ($testOrderIds);")
    $billCount = [int](Invoke-Scalar -Connection $billing -Sql "SELECT COUNT(*) FROM Bills WHERE BillID IN ($testBillIds);")

    Write-Host "Catalog test ingredients: $catalogIngredientCount"
    Write-Host "Catalog test dishes: $catalogDishCount"
    Write-Host "Catalog test tables: $catalogTableCount"
    Write-Host "Identity test customers without history: $identityCustomerCount"
    Write-Host "Order candidates: $orderCount"
    Write-Host "Bill candidates: $billCount"

    if ($WhatIf) {
        Write-Host "WhatIf enabled. No data changed."
        return
    }

    Write-Section "Catalog cleanup"
    $catalogTx = $catalog.BeginTransaction()
    try {
        Invoke-NonQuery -Connection $catalog -Transaction $catalogTx -Sql @"
DECLARE @TestIngredients TABLE (IngredientID int PRIMARY KEY);
DECLARE @TestDishes TABLE (DishID int PRIMARY KEY);
DECLARE @TestTables TABLE (TableID int PRIMARY KEY);

INSERT INTO @TestIngredients (IngredientID)
SELECT IngredientID
FROM Ingredients
WHERE Name LIKE 'ING[_]UI[_]%'
   OR Name LIKE 'ING[_]RT[_]%'
   OR Name LIKE 'AUTO[_]ING%';

INSERT INTO @TestDishes (DishID)
SELECT DishID
FROM Dishes
WHERE Name LIKE 'AUTO[_]ADMIN[_]TEST%'
   OR Name LIKE 'AUTO[_]CHEF[_]%'
   OR Name LIKE 'AUTO[_]DISH%';

INSERT INTO @TestTables (TableID)
SELECT TableID
FROM DiningTables
WHERE QRCode LIKE 'AUTO-%'
   OR UPPER(ISNULL(QRCode, '')) LIKE 'CODEX-TB-TEST%';

DELETE FROM BusinessAuditLogs
WHERE DishId IN (SELECT DishID FROM @TestDishes)
   OR TableId IN (SELECT TableID FROM @TestTables)
   OR (EntityType = 'INGREDIENT' AND TRY_CONVERT(int, EntityId) IN (SELECT IngredientID FROM @TestIngredients));

DELETE FROM CategoryDish
WHERE DishID IN (SELECT DishID FROM @TestDishes);

DELETE FROM DishIngredients
WHERE DishID IN (SELECT DishID FROM @TestDishes)
   OR IngredientID IN (SELECT IngredientID FROM @TestIngredients);

DELETE FROM Dishes
WHERE DishID IN (SELECT DishID FROM @TestDishes);

DELETE FROM Ingredients
WHERE IngredientID IN (SELECT IngredientID FROM @TestIngredients);

DELETE FROM DiningTables
WHERE TableID IN (SELECT TableID FROM @TestTables);
"@ | Out-Null

        Invoke-NonQuery -Connection $catalog -Transaction $catalogTx -Sql @"
UPDATE t
SET t.CurrentOrderID = NULL,
    t.StatusID = s.StatusID,
    t.UpdatedAt = GETDATE()
FROM DiningTables t
CROSS APPLY (
    SELECT TOP 1 StatusID
    FROM TableStatus
    WHERE StatusCode = 'AVAILABLE'
) s
WHERE t.CurrentOrderID IN ($testOrderIds);
"@ | Out-Null

        $catalogTx.Commit()
    }
    catch {
        $catalogTx.Rollback()
        throw
    }

    Write-Section "Identity cleanup"
    $identityTx = $identity.BeginTransaction()
    try {
        Invoke-NonQuery -Connection $identity -Transaction $identityTx -Sql @"
DECLARE @TestCustomers TABLE (CustomerID int PRIMARY KEY);

INSERT INTO @TestCustomers (CustomerID)
SELECT c.CustomerID
FROM Customers c
WHERE (
        c.Username LIKE 'autocus%'
        OR c.Username LIKE 'cusd[_]%'
        OR c.Username IN ('test123', 'test', 'testquang')
        OR c.Name LIKE 'test%'
     )
  AND NOT EXISTS (SELECT 1 FROM [RESTAURANT_ORDERS].dbo.Orders o WHERE o.CustomerID = c.CustomerID)
  AND NOT EXISTS (SELECT 1 FROM [RESTAURANT_BILLING].dbo.Bills b WHERE b.CustomerID = c.CustomerID);

DELETE FROM PasswordResetTokens
WHERE CustomerID IN (SELECT CustomerID FROM @TestCustomers);

DELETE FROM LoyaltyCards
WHERE CustomerID IN (SELECT CustomerID FROM @TestCustomers);

DELETE FROM Customers
WHERE CustomerID IN (SELECT CustomerID FROM @TestCustomers);

DELETE FROM Employees
WHERE Username LIKE 'autoemp%'
   OR Name LIKE 'Auto Employee%';
"@ | Out-Null

        $identityTx.Commit()
    }
    catch {
        $identityTx.Rollback()
        throw
    }

    Write-Section "Orders cleanup"
    $ordersTx = $orders.BeginTransaction()
    try {
        Invoke-NonQuery -Connection $orders -Transaction $ordersTx -Sql @"
DELETE FROM BusinessAuditLogs WHERE OrderId IN ($testOrderIds);
DELETE FROM SubmitCommands WHERE OrderId IN ($testOrderIds);
DELETE FROM OutboxEvents
WHERE PayloadJson LIKE '%\"orderId\":287%'
   OR PayloadJson LIKE '%\"orderId\":288%'
   OR PayloadJson LIKE '%\"orderId\":289%'
   OR PayloadJson LIKE '%\"orderId\":290%'
   OR PayloadJson LIKE '%\"orderId\":291%';
DELETE FROM OrderItems WHERE OrderID IN ($testOrderIds);
DELETE FROM Orders WHERE OrderID IN ($testOrderIds);
"@ | Out-Null

        $ordersTx.Commit()
    }
    catch {
        $ordersTx.Rollback()
        throw
    }

    Write-Section "Billing cleanup"
    $billingTx = $billing.BeginTransaction()
    try {
        Invoke-NonQuery -Connection $billing -Transaction $billingTx -Sql @"
DELETE FROM BusinessAuditLogs
WHERE OrderId IN ($testOrderIds)
   OR BillId IN ($testBillIds);

DELETE FROM OutboxEvents
WHERE PayloadJson LIKE '%\"orderId\":291%'
   OR PayloadJson LIKE '%\"billId\":137%';

DELETE FROM OrderContextSnapshots WHERE OrderId IN ($testOrderIds);
DELETE FROM CheckoutCommands WHERE OrderId IN ($testOrderIds);
DELETE FROM Bills WHERE BillID IN ($testBillIds) OR OrderID IN ($testOrderIds);
"@ | Out-Null

        $billingTx.Commit()
    }
    catch {
        $billingTx.Rollback()
        throw
    }

    Write-Section "Postcheck"
    Write-Host ("Remaining catalog test ingredients: " + (Invoke-Scalar -Connection $catalog -Sql @"
SELECT COUNT(*)
FROM Ingredients
WHERE Name LIKE 'ING[_]UI[_]%'
   OR Name LIKE 'ING[_]RT[_]%'
   OR Name LIKE 'AUTO[_]ING%'
"@))
    Write-Host ("Remaining catalog test dishes: " + (Invoke-Scalar -Connection $catalog -Sql @"
SELECT COUNT(*)
FROM Dishes
WHERE Name LIKE 'AUTO[_]ADMIN[_]TEST%'
   OR Name LIKE 'AUTO[_]CHEF[_]%'
   OR Name LIKE 'AUTO[_]DISH%'
"@))
    Write-Host ("Remaining catalog test tables: " + (Invoke-Scalar -Connection $catalog -Sql @"
SELECT COUNT(*)
FROM DiningTables
WHERE QRCode LIKE 'AUTO-%'
   OR UPPER(ISNULL(QRCode, '')) LIKE 'CODEX-TB-TEST%'
"@))
    Write-Host ("Remaining identity test customers: " + (Invoke-Scalar -Connection $identity -Sql @"
SELECT COUNT(*)
FROM Customers
WHERE Username LIKE 'autocus%'
   OR Username LIKE 'cusd[_]%'
   OR Username IN ('test123', 'test', 'testquang')
   OR Name LIKE 'test%'
"@))
    Write-Host ("Remaining test orders: " + (Invoke-Scalar -Connection $orders -Sql "SELECT COUNT(*) FROM Orders WHERE OrderID IN ($testOrderIds);"))
    Write-Host ("Remaining test bills: " + (Invoke-Scalar -Connection $billing -Sql "SELECT COUNT(*) FROM Bills WHERE BillID IN ($testBillIds) OR OrderID IN ($testOrderIds);"))
}
finally {
    $catalog.Close()
    $identity.Close()
    $orders.Close()
    $billing.Close()
}
