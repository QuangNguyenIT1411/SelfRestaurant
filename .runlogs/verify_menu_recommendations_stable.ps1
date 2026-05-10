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

$baseUrl = "http://localhost:5100"
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession

$login = Invoke-Json -Uri "$baseUrl/api/gateway/customer/auth/login" -Method POST -Body @{
    username = "quang"
    password = "123456"
} -WebSession $session

$branches = Invoke-Json -Uri "$baseUrl/api/gateway/customer/branches" -WebSession $session
$branch = @($branches.Body)[0]
$tables = Invoke-Json -Uri "$baseUrl/api/gateway/customer/branches/$($branch.branchId)/tables" -WebSession $session
$table = @($tables.Body.tables) | Where-Object { $_.isAvailable } | Select-Object -First 1
if ($null -eq $table) { throw "Không tìm thấy bàn trống để kiểm thử." }

$context = Invoke-Json -Uri "$baseUrl/api/gateway/customer/context/table" -Method POST -Body @{
    tableId = [int]$table.tableId
    branchId = [int]$branch.branchId
} -WebSession $session

$menu = Invoke-Json -Uri "$baseUrl/api/gateway/customer/menu" -WebSession $session
$recommendationsBefore = Invoke-Json -Uri "$baseUrl/api/gateway/customer/menu/recommendations" -WebSession $session

$firstDish = @($menu.Body.menu.categories | ForEach-Object { $_.dishes }) | Where-Object { $_.available } | Select-Object -First 1
if ($null -eq $firstDish) { throw "Không tìm thấy món còn bán để kiểm thử giỏ hàng." }

$addItem = Invoke-Json -Uri "$baseUrl/api/gateway/customer/order/items" -Method POST -Body @{
    dishId = [int]$firstDish.dishId
    quantity = 1
} -WebSession $session

$orderItemsAfterAdd = Invoke-Json -Uri "$baseUrl/api/gateway/customer/order/items" -WebSession $session
$addedItem = @($orderItemsAfterAdd.Body.items) | Where-Object { $_.dishId -eq $firstDish.dishId } | Select-Object -First 1
if ($null -eq $addedItem) { throw "Không thấy món vừa thêm trong giỏ hàng." }

$removeItem = Invoke-Json -Uri "$baseUrl/api/gateway/customer/order/items/$($addedItem.itemId)" -Method DELETE -WebSession $session
$orderItemsAfterRemove = Invoke-Json -Uri "$baseUrl/api/gateway/customer/order/items" -WebSession $session

$customerApp = Invoke-WebRequest -UseBasicParsing -Uri "$baseUrl/app/customer/" -WebSession $session
$bundlePath = [regex]::Match($customerApp.Content, 'assets/index-[^"\'' ]+\.js').Value
$bundleContent = if ($bundlePath) { (Invoke-WebRequest -UseBasicParsing -Uri "$baseUrl/app/customer/$bundlePath" -WebSession $session).Content } else { "" }

$beforeIds = @($recommendationsBefore.Body.recommendations | ForEach-Object { $_.dishId })

[pscustomobject]@{
    LoginStatus = $login.StatusCode
    SetContextStatus = $context.StatusCode
    RecommendationLoadStatus = $recommendationsBefore.StatusCode
    RecommendationCount = @($recommendationsBefore.Body.recommendations).Count
    RecommendationDishIds = $beforeIds
    AddItemStatus = $addItem.StatusCode
    RemoveItemStatus = $removeItem.StatusCode
    CartContainsAddedItemAfterAdd = ($null -ne $addedItem)
    CartContainsAddedItemAfterRemove = (@($orderItemsAfterRemove.Body.items) | Where-Object { $_.dishId -eq $firstDish.dishId }).Count -gt 0
    ServedBundlePath = $bundlePath
    ServedBundleHasStableRecommendationKey = ($bundleContent -match 'menuRecommendations",te\?\.branchId,te\?\.tableId,ee' -and $bundleContent -notmatch 'guestCartItems\.map')
} | ConvertTo-Json -Depth 10
