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
    if (-not $response.Content) { return $null }
    return ($response.Content | ConvertFrom-Json)
}

function Invoke-DataTable {
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
        $da = New-Object System.Data.SqlClient.SqlDataAdapter($cmd)
        $dt = New-Object System.Data.DataTable
        [void]$da.Fill($dt)
        return $dt
    }
    finally {
        $conn.Close()
    }
}

$baseUrl = "http://localhost:5100"
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession

$null = Invoke-Json -Uri "$baseUrl/api/gateway/customer/auth/login" -Method POST -Body @{
    username = "quang"
    password = "123456"
} -WebSession $session

$branches = @(Invoke-Json -Uri "$baseUrl/api/gateway/customer/branches" -WebSession $session)
$branch = $branches[0]
$tablesResponse = Invoke-Json -Uri "$baseUrl/api/gateway/customer/branches/$($branch.branchId)/tables" -WebSession $session
$table = @($tablesResponse.tables) | Where-Object { $_.isAvailable } | Select-Object -First 1
if ($null -eq $table) { throw "Không tìm thấy bàn trống để điều tra menu." }

$null = Invoke-Json -Uri "$baseUrl/api/gateway/customer/context/table" -Method POST -Body @{
    tableId = [int]$table.tableId
    branchId = [int]$branch.branchId
} -WebSession $session

$menu = Invoke-Json -Uri "$baseUrl/api/gateway/customer/menu" -WebSession $session
$menuRows = foreach ($category in $menu.menu.categories) {
    foreach ($dish in $category.dishes) {
        [pscustomobject]@{
            branchId = $menu.menu.branchId
            branchName = $menu.menu.branchName
            categoryId = $category.categoryId
            categoryName = $category.categoryName
            dishId = $dish.dishId
            name = $dish.name
            available = $dish.available
        }
    }
}

$suspiciousMenuRows = @($menuRows | Where-Object {
    $_.name -like '*Dưa hấu*' -or
    $_.name -like 'DbgUpload*' -or
    $_.name -like '*Upload*' -or
    $_.name -like '*dbg*'
})

$dishDt = Invoke-DataTable -Database "RESTAURANT_CATALOG" -Sql @"
SELECT d.DishID,d.Name,d.CategoryID,c.Name AS CategoryName,d.IsActive,d.Available,d.CreatedAt,d.UpdatedAt
FROM Dishes d
JOIN Categories c ON c.CategoryID=d.CategoryID
WHERE d.Name LIKE N'%Dưa hấu%'
   OR d.Name LIKE N'DbgUpload%'
   OR d.Name LIKE N'%Upload%'
   OR d.Name LIKE N'%dbg%'
ORDER BY d.DishID;
"@

$dishRecords = @($dishDt.Rows | ForEach-Object {
    [pscustomobject]@{
        DishID = [int]$_.DishID
        Name = [string]$_.Name
        CategoryID = [int]$_.CategoryID
        CategoryName = [string]$_.CategoryName
        IsActive = [bool]$_.IsActive
        Available = [bool]$_.Available
        CreatedAt = if ($_.CreatedAt -is [System.DBNull]) { $null } else { $_.CreatedAt }
        UpdatedAt = if ($_.UpdatedAt -is [System.DBNull]) { $null } else { $_.UpdatedAt }
    }
})

$linkDt = Invoke-DataTable -Database "RESTAURANT_CATALOG" -Sql @"
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

$linkRecords = @($linkDt.Rows | ForEach-Object {
    [pscustomobject]@{
        DishID = [int]$_.DishID
        Name = [string]$_.Name
        MenuCategoryID = [int]$_.MenuCategoryID
        MenuID = [int]$_.MenuID
        CategoryID = [int]$_.CategoryID
        CategoryName = [string]$_.CategoryName
        CategoryDishID = [int]$_.CategoryDishID
        IsAvailable = [bool]$_.IsAvailable
        MenuCategoryActive = [bool]$_.MenuCategoryActive
        BranchID = [int]$_.BranchID
        Date = if ($_.Date -is [System.DBNull]) { $null } else { $_.Date }
        MenuActive = [bool]$_.MenuActive
    }
})

[pscustomobject]@{
    MenuBranchId = $menu.menu.branchId
    MenuBranchName = $menu.menu.branchName
    SuspiciousMenuRows = $suspiciousMenuRows
    SuspiciousDishRecords = $dishRecords
    SuspiciousCategoryLinks = $linkRecords
} | ConvertTo-Json -Depth 10
