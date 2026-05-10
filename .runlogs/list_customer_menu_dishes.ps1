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
    return ($response.Content | ConvertFrom-Json)
}

$baseUrl = "http://localhost:5100"
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession

$null = Invoke-Json -Uri "$baseUrl/api/gateway/customer/auth/login" -Method POST -Body @{
    username = "quang"
    password = "123456"
} -WebSession $session

$branches = @(Invoke-Json -Uri "$baseUrl/api/gateway/customer/branches" -WebSession $session)
$result = foreach ($branch in $branches) {
    $tablesResponse = Invoke-Json -Uri "$baseUrl/api/gateway/customer/branches/$($branch.branchId)/tables" -WebSession $session
    $table = @($tablesResponse.tables) | Where-Object { $_.isAvailable } | Select-Object -First 1
    if ($null -eq $table) { continue }

    $null = Invoke-Json -Uri "$baseUrl/api/gateway/customer/context/table" -Method POST -Body @{
        tableId = [int]$table.tableId
        branchId = [int]$branch.branchId
    } -WebSession $session

    $menu = Invoke-Json -Uri "$baseUrl/api/gateway/customer/menu" -WebSession $session
    foreach ($category in $menu.menu.categories) {
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
}

$result | Sort-Object branchId, categoryId, dishId | ConvertTo-Json -Depth 10
