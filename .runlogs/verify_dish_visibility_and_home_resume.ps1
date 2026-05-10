$ErrorActionPreference = "Stop"

function Invoke-Json {
    param(
        [Parameter(Mandatory = $true)][string]$Uri,
        [string]$Method = "GET",
        [object]$Body = $null,
        $WebSession = $null
    )

    $params = @{
        Uri             = $Uri
        Method          = $Method
        Headers         = @{ "Content-Type" = "application/json" }
        UseBasicParsing = $true
    }

    if ($null -ne $WebSession) {
        $params.WebSession = $WebSession
    }

    if ($null -ne $Body) {
        $params.Body = ($Body | ConvertTo-Json -Depth 10 -Compress)
    }

    try {
        $response = Invoke-WebRequest @params
    }
    catch {
        $statusCode = $null
        $body = $null
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $body = $reader.ReadToEnd()
            $reader.Dispose()
        }

        throw "Request failed: $Method $Uri => $statusCode $body"
    }
    $payload = if ($response.Content) { $response.Content | ConvertFrom-Json } else { $null }

    [pscustomobject]@{
        StatusCode = [int]$response.StatusCode
        Body       = $payload
    }
}

function Find-AvailableTable {
    param(
        [string]$BaseUrl,
        $WebSession
    )

    $branches = Invoke-Json -Uri "$BaseUrl/api/gateway/customer/branches" -WebSession $WebSession
    foreach ($branch in $branches.Body) {
        $tables = Invoke-Json -Uri "$BaseUrl/api/gateway/customer/branches/$($branch.branchId)/tables" -WebSession $WebSession
        $table = @($tables.Body.tables) | Where-Object { $_.isAvailable } | Select-Object -First 1
        if ($null -ne $table) {
            return [pscustomobject]@{
                Branch = $branch
                Table  = $table
            }
        }
    }

    throw "Không tìm thấy bàn trống để kiểm thử."
}

$baseUrl = "http://localhost:5100"

$adminSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$customerSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession

Write-Host "Admin login..."
$adminLogin = Invoke-Json -Uri "$baseUrl/api/gateway/staff/auth/login" -Method POST -Body @{
    username = "admin"
    password = "123456"
} -WebSession $adminSession

if (-not $adminLogin.Body.success) {
    throw "Đăng nhập admin thất bại."
}

$dishPage = Invoke-Json -Uri "$baseUrl/api/gateway/admin/dishes?page=1&pageSize=50&includeInactive=true" -WebSession $adminSession
Write-Host "Resolved target dish and admin session."
$targetDish = @($dishPage.Body.dishes.items) |
    Where-Object { $_.isActive -and $_.available } |
    Select-Object -First 1

if ($null -eq $targetDish) {
    throw "Không tìm thấy món đang hoạt động để kiểm thử."
}

$originalDish = [ordered]@{
    name           = $targetDish.name
    price          = [decimal]$targetDish.price
    categoryId     = [int]$targetDish.categoryId
    description    = $targetDish.description
    unit           = $targetDish.unit
    image          = $targetDish.image
    isVegetarian   = [bool]$targetDish.isVegetarian
    isDailySpecial = [bool]$targetDish.isDailySpecial
    available      = [bool]$targetDish.available
    isActive       = [bool]$targetDish.isActive
}

$selection = Find-AvailableTable -BaseUrl $baseUrl -WebSession $customerSession
Write-Host "Selected available table."
$setContext = Invoke-Json -Uri "$baseUrl/api/gateway/customer/context/table" -Method POST -Body @{
    tableId  = [int]$selection.Table.tableId
    branchId = [int]$selection.Branch.branchId
} -WebSession $customerSession

$menuBefore = Invoke-Json -Uri "$baseUrl/api/gateway/customer/menu" -WebSession $customerSession
Write-Host "Captured customer menu before deactivate."
$dishBefore = @($menuBefore.Body.menu.categories | ForEach-Object { $_.dishes }) | Where-Object { $_.dishId -eq $targetDish.dishId } | Select-Object -First 1
if ($null -eq $dishBefore) {
    throw "Món kiểm thử không xuất hiện trong menu trước khi vô hiệu."
}

$deactivate = Invoke-Json -Uri "$baseUrl/api/gateway/admin/dishes/$($targetDish.dishId)/deactivate" -Method POST -Body @{} -WebSession $adminSession
Write-Host "Deactivated dish."
$menuAfterDeactivate = Invoke-Json -Uri "$baseUrl/api/gateway/customer/menu" -WebSession $customerSession
$dishAfterDeactivate = @($menuAfterDeactivate.Body.menu.categories | ForEach-Object { $_.dishes }) | Where-Object { $_.dishId -eq $targetDish.dishId } | Select-Object -First 1

$restoreAfterDeactivate = Invoke-Json -Uri "$baseUrl/api/gateway/admin/dishes/$($targetDish.dishId)" -Method PUT -Body $originalDish -WebSession $adminSession
Write-Host "Restored dish after deactivate."

$pause = Invoke-Json -Uri "$baseUrl/api/gateway/admin/dishes/$($targetDish.dishId)/availability" -Method POST -Body @{ available = $false } -WebSession $adminSession
Write-Host "Paused dish availability."
$menuAfterPause = Invoke-Json -Uri "$baseUrl/api/gateway/customer/menu" -WebSession $customerSession
$dishAfterPause = @($menuAfterPause.Body.menu.categories | ForEach-Object { $_.dishes }) | Where-Object { $_.dishId -eq $targetDish.dishId } | Select-Object -First 1

$restoreAfterPause = Invoke-Json -Uri "$baseUrl/api/gateway/admin/dishes/$($targetDish.dishId)" -Method PUT -Body $originalDish -WebSession $adminSession
Write-Host "Restored dish after pause."

$homeRoute = Invoke-WebRequest -UseBasicParsing -Uri "$baseUrl/Home/Index" -WebSession $customerSession
$sessionBeforeSync = Invoke-Json -Uri "$baseUrl/api/gateway/customer/session" -WebSession $customerSession
$syncResponse = Invoke-Json -Uri "$baseUrl/api/gateway/customer/session/sync-active-order" -Method POST -Body @{} -WebSession $customerSession
Write-Host "Synced session from active order."
$sessionAfterSync = Invoke-Json -Uri "$baseUrl/api/gateway/customer/session" -WebSession $customerSession
$homeNewOrderRoute = Invoke-WebRequest -UseBasicParsing -Uri "$baseUrl/Home/Index?flow=new-order" -WebSession $customerSession

$customerAssets = Invoke-WebRequest -UseBasicParsing -Uri "$baseUrl/app/customer/" -WebSession $customerSession
$bundlePath = [regex]::Match($customerAssets.Content, '/app/customer/assets/index-[^"]+\.js').Value
$bundleContent = if ($bundlePath) { (Invoke-WebRequest -UseBasicParsing -Uri "$baseUrl$bundlePath" -WebSession $customerSession).Content } else { "" }

[pscustomobject]@{
    Task1 = [pscustomobject]@{
        DishId = [int]$targetDish.dishId
        DishName = [string]$targetDish.name
        Deactivate = [pscustomobject]@{
            StatusCode = $deactivate.StatusCode
            Message = $deactivate.Body.message
            VisibleInCustomerMenu = ($null -ne $dishAfterDeactivate)
            AvailableInCustomerMenu = if ($null -ne $dishAfterDeactivate) { [bool]$dishAfterDeactivate.available } else { $null }
        }
        Pause = [pscustomobject]@{
            StatusCode = $pause.StatusCode
            Message = $pause.Body.message
            VisibleInCustomerMenu = ($null -ne $dishAfterPause)
            AvailableInCustomerMenu = if ($null -ne $dishAfterPause) { [bool]$dishAfterPause.available } else { $null }
        }
        RestoreDeactivate = [pscustomobject]@{
            StatusCode = $restoreAfterDeactivate.StatusCode
            Message = $restoreAfterDeactivate.Body.message
        }
        RestorePause = [pscustomobject]@{
            StatusCode = $restoreAfterPause.StatusCode
            Message = $restoreAfterPause.Body.message
        }
    }
    Task2 = [pscustomobject]@{
        BranchId = [int]$selection.Branch.branchId
        TableId = [int]$selection.Table.tableId
        SetContextStatus = $setContext.StatusCode
        HomeRouteStatus = [int]$homeRoute.StatusCode
        HomeNewOrderRouteStatus = [int]$homeNewOrderRoute.StatusCode
        SessionBeforeSync = $sessionBeforeSync.Body.tableContext
        SyncStatus = $syncResponse.StatusCode
        SessionAfterSync = $sessionAfterSync.Body.tableContext
        ServedBundleHasNewOrderBypass = ($bundleContent -match 'flow=new-order') -and ($bundleContent -match 'tableContext\|\|C\.isPending\|\|C\.mutate\(\)')
    }
} | ConvertTo-Json -Depth 10
