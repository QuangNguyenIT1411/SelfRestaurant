$ErrorActionPreference = "Stop"

function Invoke-ReaderRows {
    param(
        [Parameter(Mandatory = $true)][string]$Database,
        [Parameter(Mandatory = $true)][string]$Sql
    )

    $conn = New-Object System.Data.SqlClient.SqlConnection("Server=(localdb)\MSSQLLocalDB;Database=$Database;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=True")
    $conn.Open()
    try {
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = $Sql
        $cmd.CommandTimeout = 60
        $reader = $cmd.ExecuteReader()
        $rows = @()
        while ($reader.Read()) {
            $obj = [ordered]@{}
            for ($i = 0; $i -lt $reader.FieldCount; $i++) {
                $name = $reader.GetName($i)
                $value = if ($reader.IsDBNull($i)) { $null } else { $reader.GetValue($i) }
                $obj[$name] = $value
            }
            $rows += [pscustomobject]$obj
        }
        $reader.Close()
        return $rows
    }
    finally {
        $conn.Close()
    }
}

$ids = "2142,2143,3146"

$dishSql = @"
SELECT d.DishID,d.Name,d.CategoryID,c.Name AS CategoryName,d.IsActive,d.Available,d.CreatedAt,d.UpdatedAt
FROM Dishes d
JOIN Categories c ON c.CategoryID=d.CategoryID
WHERE d.DishID IN ($ids)
ORDER BY d.DishID;
"@

$linkSql = @"
SELECT d.DishID,d.Name,mc.MenuCategoryID,mc.MenuID,mc.CategoryID,c.Name AS CategoryName,cd.CategoryDishID,cd.IsAvailable,
       mc.IsActive AS MenuCategoryActive,m.BranchID,m.Date,m.IsActive AS MenuActive
FROM Dishes d
JOIN CategoryDish cd ON cd.DishID=d.DishID
JOIN MenuCategory mc ON mc.MenuCategoryID=cd.MenuCategoryID
JOIN Menus m ON m.MenuID=mc.MenuID
JOIN Categories c ON c.CategoryID=mc.CategoryID
WHERE d.DishID IN ($ids)
ORDER BY d.DishID,m.BranchID,mc.MenuID;
"@

$ingredientsSql = @"
SELECT di.DishID, di.DishIngredientID, di.IngredientID, i.Name AS IngredientName, di.QuantityPerDish
FROM DishIngredients di
JOIN Ingredients i ON i.IngredientID = di.IngredientID
WHERE di.DishID IN ($ids)
ORDER BY di.DishID, di.DishIngredientID;
"@

$orderSql = @"
SELECT oi.DishID, COUNT(*) AS OrderItemCount, MIN(o.OrderTime) AS FirstOrderTime, MAX(o.OrderTime) AS LastOrderTime
FROM OrderItems oi
JOIN Orders o ON o.OrderID=oi.OrderID
WHERE oi.DishID IN ($ids)
GROUP BY oi.DishID
ORDER BY oi.DishID;
"@

[pscustomobject]@{
    Dishes = @(Invoke-ReaderRows -Database "RESTAURANT_CATALOG" -Sql $dishSql)
    Links = @(Invoke-ReaderRows -Database "RESTAURANT_CATALOG" -Sql $linkSql)
    Ingredients = @(Invoke-ReaderRows -Database "RESTAURANT_CATALOG" -Sql $ingredientsSql)
    OrderReferences = @(Invoke-ReaderRows -Database "RESTAURANT_ORDERS" -Sql $orderSql)
} | ConvertTo-Json -Depth 10
