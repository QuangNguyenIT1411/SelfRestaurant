$ErrorActionPreference = "Stop"

function Invoke-Json {
    param(
        [Parameter(Mandatory = $true)][string]$Uri,
        [string]$Method = "GET",
        [object]$Body = $null,
        [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession
    )

    $params = @{
        Uri             = $Uri
        Method          = $Method
        UseBasicParsing = $true
        WebSession      = $WebSession
        Headers         = @{ "Content-Type" = "application/json" }
    }

    if ($null -ne $Body) {
        $params.Body = ($Body | ConvertTo-Json -Depth 10 -Compress)
    }

    $response = Invoke-WebRequest @params
    [pscustomobject]@{
        StatusCode = [int]$response.StatusCode
        Body = if ($response.Content) { $response.Content | ConvertFrom-Json } else { $null }
    }
}

function Invoke-TableJson {
    param(
        [Parameter(Mandatory = $true)][string]$Database,
        [Parameter(Mandatory = $true)][string]$Sql
    )

    $conn = New-Object System.Data.SqlClient.SqlConnection("Server=(localdb)\MSSQLLocalDB;Database=$Database;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=True")
    $conn.Open()
    try {
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = $Sql
        $cmd.CommandTimeout = 120
        $da = New-Object System.Data.SqlClient.SqlDataAdapter($cmd)
        $dt = New-Object System.Data.DataTable
        [void]$da.Fill($dt)
        return ($dt | ConvertTo-Json -Depth 10)
    }
    finally {
        $conn.Close()
    }
}

$baseUrl = "http://localhost:5100"
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession

Write-Host "Login customer..."
$null = Invoke-Json -Uri "$baseUrl/api/gateway/customer/auth/login" -Method POST -Body @{
    username = "quang"
    password = "123456"
} -WebSession $session

Write-Host "Load branches/tables..."
$branches = Invoke-Json -Uri "$baseUrl/api/gateway/customer/branches" -WebSession $session
$branch = @($branches.Body)[0]
$tables = Invoke-Json -Uri "$baseUrl/api/gateway/customer/branches/$($branch.branchId)/tables" -WebSession $session
$table = @($tables.Body.tables) | Where-Object { $_.isAvailable } | Select-Object -First 1
if ($null -eq $table) { throw "Không tìm thấy bàn trống để điều tra menu." }

Write-Host "Set context and load menu..."
$null = Invoke-Json -Uri "$baseUrl/api/gateway/customer/context/table" -Method POST -Body @{
    tableId = [int]$table.tableId
    branchId = [int]$branch.branchId
} -WebSession $session

$menu = Invoke-Json -Uri "$baseUrl/api/gateway/customer/menu" -WebSession $session
$menuRows = foreach ($category in $menu.Body.menu.categories) {
    foreach ($dish in $category.dishes) {
        [pscustomobject]@{
            branchId = $menu.Body.menu.branchId
            branchName = $menu.Body.menu.branchName
            categoryId = $category.categoryId
            categoryName = $category.categoryName
            dishId = $dish.dishId
            name = $dish.name
            available = $dish.available
        }
    }
}

$suspiciousMenuRows = $menuRows | Where-Object {
    $_.name -like '*Dưa hấu*' -or
    $_.name -like 'DbgUpload*' -or
    $_.name -like '*Upload*' -or
    $_.name -like '*dbg*'
}

Write-Host "Query catalog suspicious dish rows..."

$dishSql = @"
SELECT d.DishID,d.Name,d.CategoryID,c.Name AS CategoryName,d.IsActive,d.Available,d.CreatedAt,d.UpdatedAt
FROM Dishes d
JOIN Categories c ON c.CategoryID=d.CategoryID
WHERE d.Name LIKE N'%Dưa hấu%'
   OR d.Name LIKE N'DbgUpload%'
   OR d.Name LIKE N'%Upload%'
   OR d.Name LIKE N'%dbg%'
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
WHERE d.Name LIKE N'%Dưa hấu%'
   OR d.Name LIKE N'DbgUpload%'
   OR d.Name LIKE N'%Upload%'
   OR d.Name LIKE N'%dbg%'
ORDER BY d.DishID,m.BranchID,mc.MenuID;
"@

Write-Host "Query category/menu links..."
$orderRefSql = @"
SELECT oi.DishID, COUNT(*) AS OrderItemCount, MIN(o.OrderTime) AS FirstOrderTime, MAX(o.OrderTime) AS LastOrderTime
FROM OrderItems oi
JOIN Orders o ON o.OrderID=oi.OrderID
WHERE oi.DishID IN (
    SELECT DishID
    FROM [RESTAURANT_CATALOG].dbo.Dishes
    WHERE Name LIKE N'%Dưa hấu%'
       OR Name LIKE N'DbgUpload%'
       OR Name LIKE N'%Upload%'
       OR Name LIKE N'%dbg%'
)
GROUP BY oi.DishID
ORDER BY oi.DishID;
"@

Write-Host "Query order references..."
[pscustomobject]@{
    MenuBranchId = $menu.Body.menu.branchId
    MenuBranchName = $menu.Body.menu.branchName
    SuspiciousMenuRows = $suspiciousMenuRows
    SuspiciousDishRecords = (Invoke-TableJson -Database "RESTAURANT_CATALOG" -Sql $dishSql | ConvertFrom-Json)
    SuspiciousCategoryLinks = (Invoke-TableJson -Database "RESTAURANT_CATALOG" -Sql $linkSql | ConvertFrom-Json)
    SuspiciousOrderReferences = (Invoke-TableJson -Database "RESTAURANT_ORDERS" -Sql $orderRefSql | ConvertFrom-Json)
} | ConvertTo-Json -Depth 10
