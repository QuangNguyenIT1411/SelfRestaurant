$ErrorActionPreference = 'Stop'

function Read-ErrorResponse($Exception) {
    $response = $Exception.Response
    if ($null -eq $response) { return [pscustomobject]@{ raw = $Exception.Message; status = 0; json = $null } }
    $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
    $raw = $reader.ReadToEnd()
    $reader.Close()
    $json = $null
    if (-not [string]::IsNullOrWhiteSpace($raw)) { try { $json = $raw | ConvertFrom-Json } catch {} }
    [pscustomobject]@{ raw = $raw; status = [int]$response.StatusCode; json = $json }
}

function Invoke-RestApi {
    param([string]$Method='GET',[string]$Url,$Session=$null,$Body=$null)
    $params = @{ Uri = $Url; Method = $Method; TimeoutSec = 60 }
    if ($null -ne $Session) { $params.WebSession = $Session }
    if ($null -ne $Body) {
        $params.ContentType = 'application/json'
        $params.Body = ($Body | ConvertTo-Json -Depth 20)
    }
    try {
        $json = Invoke-RestMethod @params
        return [pscustomobject]@{ ok = $true; status = 200; json = $json; raw = ($json | ConvertTo-Json -Depth 20 -Compress) }
    } catch {
        $err = Read-ErrorResponse $_.Exception
        return [pscustomobject]@{ ok = $false; status = $err.status; json = $err.json; raw = $err.raw }
    }
}

function Unwrap-Collection {
    param($Value)
    if ($null -eq $Value) { return @() }
    if ($null -ne $Value.PSObject.Properties['value']) { return @($Value.value) }
    if ($null -ne $Value.PSObject.Properties['items']) { return @($Value.items) }
    return @($Value)
}

$base = 'http://localhost:5100'
$guestSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$customerSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$report = [ordered]@{}
$testTableId = $null
$testBranchId = $null

try {
    $homePage = Invoke-WebRequest -Uri "$base/Home/Index" -UseBasicParsing -WebSession $guestSession -TimeoutSec 60
    $rootPage = Invoke-WebRequest -Uri "$base/" -UseBasicParsing -WebSession $guestSession -TimeoutSec 60
    $guestBranches = Invoke-RestApi -Url "$base/api/gateway/customer/branches" -Session $guestSession
    $branchList = @(Unwrap-Collection $guestBranches.json)
    if (-not $guestBranches.ok -or $branchList.Count -eq 0) { throw "Guest branches failed: $($guestBranches.raw)" }
    $branchKeyword = (($branchList | Where-Object { $_.name -match 'Quận|Quan|Thạnh|Thanh' } | Select-Object -First 1).name)
    if ([string]::IsNullOrWhiteSpace($branchKeyword)) { $branchKeyword = [string]$branchList[0].name }
    $searchMatches = @($branchList | Where-Object { $_.name -like "*$branchKeyword*" -or $_.location -like "*$branchKeyword*" })

    $testBranchId = [int]$branchList[0].branchId
    $guestTables = Invoke-RestApi -Url "$base/api/gateway/customer/branches/$testBranchId/tables" -Session $guestSession
    $tableList = @(Unwrap-Collection $guestTables.json.tables)
    $table = @($tableList | Where-Object { $_.isAvailable -eq $true } | Select-Object -First 1)
    if ($table.Count -eq 0) { $table = @($tableList | Select-Object -First 1) }
    if ($table.Count -eq 0) { throw "Guest tables failed: $($guestTables.raw)" }
    $testTableId = [int]$table[0].tableId
    $guestSetContext = Invoke-RestApi -Method POST -Url "$base/api/gateway/customer/context/table" -Session $guestSession -Body @{ tableId = $testTableId; branchId = $testBranchId }
    $guestMenu = Invoke-RestApi -Url "$base/api/gateway/customer/menu" -Session $guestSession

    $customerLogin = Invoke-RestApi -Method POST -Url "$base/api/gateway/customer/auth/login" -Session $customerSession -Body @{ username = 'lan.nguyen'; password = '123456' }
    if (-not $customerLogin.ok) { throw "Customer login failed: $($customerLogin.raw)" }
    $branches = Invoke-RestApi -Url "$base/api/gateway/customer/branches" -Session $customerSession
    $branchList2 = @(Unwrap-Collection $branches.json)
    $testBranchId = [int]$branchList2[0].branchId
    $tables = Invoke-RestApi -Url "$base/api/gateway/customer/branches/$testBranchId/tables" -Session $customerSession
    $tableList2 = @(Unwrap-Collection $tables.json.tables)
    $table2 = @($tableList2 | Where-Object { $_.isAvailable -eq $true } | Select-Object -First 1)
    if ($table2.Count -eq 0) { $table2 = @($tableList2 | Select-Object -First 1) }
    $testTableId = [int]$table2[0].tableId
    $setContext = Invoke-RestApi -Method POST -Url "$base/api/gateway/customer/context/table" -Session $customerSession -Body @{ tableId = $testTableId; branchId = $testBranchId }
    $sessionDto = Invoke-RestApi -Url "$base/api/gateway/customer/session" -Session $customerSession
    $menu = Invoke-RestApi -Url "$base/api/gateway/customer/menu" -Session $customerSession
    $menuPage = Invoke-WebRequest -Uri "$base/Menu/Index" -UseBasicParsing -WebSession $customerSession -TimeoutSec 60
    $homeNewOrder = Invoke-WebRequest -Uri "$base/Home/Index?flow=new-order" -UseBasicParsing -WebSession $customerSession -TimeoutSec 60
    $dashboardApi = Invoke-RestApi -Url "$base/api/gateway/customer/dashboard" -Session $customerSession
    $dashboardPage = Invoke-WebRequest -Uri "$base/Customer/Dashboard" -UseBasicParsing -WebSession $customerSession -TimeoutSec 60
    $recommendations = Invoke-RestApi -Url "$base/api/gateway/customer/menu/recommendations" -Session $customerSession
    $allDishes = @()
    foreach ($category in @(Unwrap-Collection $menu.json.menu.categories)) {
        foreach ($dish in @(Unwrap-Collection $category.dishes)) {
            $allDishes += $dish
        }
    }
    $availableDish = @($allDishes | Where-Object { $_.available -eq $true } | Select-Object -First 1)[0]
    $unavailableCount = @($allDishes | Where-Object { $_.available -eq $false }).Count
    $recWithIngredients = @((Unwrap-Collection $recommendations.json.recommendations) | Where-Object { $null -ne $_.ingredients -and $_.ingredients.Count -gt 0 } | Select-Object -First 1)[0]

    $noteMarker = 'REG_VERIFY_' + [DateTime]::UtcNow.ToString('yyyyMMddHHmmss')
    $addItem = Invoke-RestApi -Method POST -Url "$base/api/gateway/customer/order/items" -Session $customerSession -Body @{ dishId = [int]$availableDish.dishId; quantity = 1; note = $noteMarker }
    $orderAfterAdd = Invoke-RestApi -Url "$base/api/gateway/customer/order" -Session $customerSession
    $itemId = [int](@(Unwrap-Collection $orderAfterAdd.json.items | Where-Object { $_.dishId -eq $availableDish.dishId } | Select-Object -First 1)[0].itemId)
    $updateQty = Invoke-RestApi -Method PATCH -Url "$base/api/gateway/customer/order/items/$itemId/quantity" -Session $customerSession -Body @{ quantity = 2 }
    $orderAfterUpdate = Invoke-RestApi -Url "$base/api/gateway/customer/order/items" -Session $customerSession
    $removeItem = Invoke-RestApi -Method DELETE -Url "$base/api/gateway/customer/order/items/$itemId" -Session $customerSession
    $orderAfterRemove = Invoke-RestApi -Url "$base/api/gateway/customer/order/items" -Session $customerSession

    $indexHtml = Invoke-WebRequest -Uri "$base/" -UseBasicParsing -TimeoutSec 60
    $assetMatch = [regex]::Match([string]$indexHtml.Content, '/assets/[^"'']+\.js')
    $assetContent = ''
    $assetUrl = $null
    if ($assetMatch.Success) {
        $assetUrl = "$base$($assetMatch.Value)"
        $assetContent = [string](Invoke-WebRequest -Uri $assetUrl -UseBasicParsing -TimeoutSec 60).Content
    }

    $report = [ordered]@{
        routes = [ordered]@{
            root = [int]$rootPage.StatusCode
            home = [int]$homePage.StatusCode
            menu = [int]$menuPage.StatusCode
            dashboard = [int]$dashboardPage.StatusCode
            homeNewOrder = [int]$homeNewOrder.StatusCode
        }
        guest = [ordered]@{
            branchesLoaded = $branchList.Count
            searchKeyword = $branchKeyword
            searchMatches = $searchMatches.Count
            setContextOk = $guestSetContext.ok
            menuOk = $guestMenu.ok
        }
        customer = [ordered]@{
            loginStatus = $customerLogin.status
            sessionTableId = $sessionDto.json.tableContext.tableId
            sessionBranchId = $sessionDto.json.tableContext.branchId
            dashboardSummary = $dashboardApi.json.summary
            recentOrdersCount = @($dashboardApi.json.recentOrders).Count
        }
        menu = [ordered]@{
            categoryCount = @(Unwrap-Collection $menu.json.menu.categories).Count
            dishCount = $allDishes.Count
            unavailableDishCount = $unavailableCount
            recommendationCount = @(Unwrap-Collection $recommendations.json.recommendations).Count
            recommendationHasIngredients = ($null -ne $recWithIngredients)
            recommendationSample = $recWithIngredients
        }
        cart = [ordered]@{
            addedOrderId = $addItem.json.orderId
            addOk = $addItem.ok
            updateOk = $updateQty.ok
            updatedQuantity = @((Unwrap-Collection $orderAfterUpdate.json.items) | Where-Object { $_.itemId -eq $itemId } | Select-Object -First 1)[0].quantity
            removeOk = $removeItem.ok
            itemStillExistsAfterRemove = (@((Unwrap-Collection $orderAfterRemove.json.items) | Where-Object { $_.itemId -eq $itemId }).Count -gt 0)
        }
        bundle = [ordered]@{
            assetUrl = $assetUrl
            hasRecommendationDetailText = ($assetContent -match 'Chi tiết món')
            hasBackHomeText = ($assetContent -match 'Quay Về Trang Chủ|Quay lại trang chủ')
            hasNewOrderFlowLink = ($assetContent -match 'flow=new-order')
            servingMapsToReceivedSnippet = ($assetContent -match 'SERVING"\|\|\["SERVED","COMPLETED"\]\.includes\(c\)\?"received"')
        }
    }
}
finally {
    if ($null -ne $testTableId -and $testTableId -gt 0) {
        try { [void](Invoke-RestApi -Method POST -Url "$base/api/gateway/customer/context/table/reset" -Session $customerSession) } catch {}
        try { [void](Invoke-RestApi -Method POST -Url "$base/api/gateway/customer/context/table/reset" -Session $guestSession) } catch {}
    }
}

$report | ConvertTo-Json -Depth 10
