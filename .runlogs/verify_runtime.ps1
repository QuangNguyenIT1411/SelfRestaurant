$ErrorActionPreference = 'Stop'

function Read-ErrorResponse($Exception) {
    $response = $Exception.Response
    if ($null -eq $response) { return [pscustomobject]@{ raw = $Exception.Message; json = $null; status = 0 } }
    $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
    $raw = $reader.ReadToEnd()
    $reader.Close()
    $json = $null
    if (-not [string]::IsNullOrWhiteSpace($raw)) { try { $json = $raw | ConvertFrom-Json } catch {} }
    return [pscustomobject]@{ raw = $raw; json = $json; status = [int]$response.StatusCode }
}

function Invoke-RestApi {
    param(
        [string]$Method = 'GET',
        [Parameter(Mandatory=$true)][string]$Url,
        $Session,
        $Body = $null
    )

    $params = @{ Uri = $Url; Method = $Method; WebSession = $Session }
    if ($null -ne $Body) {
        $params.ContentType = 'application/json'
        $params.Body = ($Body | ConvertTo-Json -Depth 20)
    }

    try {
        $json = Invoke-RestMethod @params
        return [pscustomobject]@{ ok = $true; status = 200; json = $json; raw = ($json | ConvertTo-Json -Depth 20 -Compress) }
    }
    catch {
        $err = Read-ErrorResponse $_.Exception
        return [pscustomobject]@{ ok = $false; status = $err.status; json = $err.json; raw = $err.raw }
    }
}

function Invoke-WebText {
    param([string]$Url, $Session)
    return Invoke-WebRequest -Uri $Url -UseBasicParsing -WebSession $Session
}

function As-Array {
    param($Value)
    if ($null -eq $Value) { return @() }
    return @($Value | ForEach-Object { $_ })
}

function Unwrap-Collection {
    param($Value)
    if ($null -eq $Value) { return @() }
    if ($null -ne $Value.PSObject.Properties['value']) { return @(As-Array $Value.value) }
    if ($null -ne $Value.PSObject.Properties['items']) { return @(As-Array $Value.items) }
    return @(As-Array $Value)
}

$base = 'http://localhost:5100'
$customerSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$adminSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$report = [ordered]@{}

# Task 1
$customerLogin = Invoke-RestApi -Method POST -Url "$base/api/gateway/customer/auth/login" -Session $customerSession -Body @{ username = 'lan.nguyen'; password = '123456' }
if (-not $customerLogin.ok) { throw "Customer login failed: $($customerLogin.raw)" }
$branches = Invoke-RestApi -Url "$base/api/gateway/customer/branches" -Session $customerSession
$branchList = @(Unwrap-Collection $branches.json)
if (-not $branches.ok -or $branchList.Count -eq 0) { throw "Branches request failed or returned empty: $($branches.raw)" }
$branchId = [int]$branchList[0].branchId
$tables = Invoke-RestApi -Url "$base/api/gateway/customer/branches/$branchId/tables" -Session $customerSession
$tableList = @(Unwrap-Collection $tables.json.tables)
$table = @($tableList | Where-Object { $_.isAvailable -eq $true } | Select-Object -First 1)
if ($table.Count -eq 0) { $table = @($tableList | Select-Object -First 1) }
if ($table.Count -eq 0) { throw "Tables request failed or returned empty: $($tables.raw)" }
$tableId = [int]$table[0].tableId
$tableNumber = [int]$table[0].displayTableNumber
$setContext = Invoke-RestApi -Method POST -Url "$base/api/gateway/customer/context/table" -Session $customerSession -Body @{ tableId = $tableId; branchId = $branchId }
if (-not $setContext.ok) { throw "Set table context failed: $($setContext.raw)" }
$menu = Invoke-RestApi -Url "$base/api/gateway/customer/menu" -Session $customerSession
$recommendations = Invoke-RestApi -Url "$base/api/gateway/customer/menu/recommendations" -Session $customerSession
if (-not $menu.ok -or -not $recommendations.ok) { throw "Menu or recommendations request failed" }
$menuDishes = @()
foreach ($category in @((Unwrap-Collection $menu.json.menu.categories))) {
    foreach ($dish in @((Unwrap-Collection $category.dishes))) {
        $dish | Add-Member -NotePropertyName categoryId -NotePropertyValue $category.categoryId -Force
        $menuDishes += $dish
    }
}
$recommended = @((Unwrap-Collection $recommendations.json.recommendations))
$recDish = @($recommended | Where-Object { $null -ne $_.ingredients -and $_.ingredients.Count -gt 0 } | Select-Object -First 1)[0]
if ($null -eq $recDish) { $recDish = @($recommended | Select-Object -First 1)[0] }
$menuMatch = @($menuDishes | Where-Object { [int]$_.dishId -eq [int]$recDish.dishId } | Select-Object -First 1)[0]
$ingredientNames = @($recDish.ingredients | ForEach-Object { $_.name })
$descMatchesMenu = $false
$ingredientNamesMatchMenu = $false
if ($null -ne $menuMatch) {
    $descMatchesMenu = ([string]$menuMatch.description -eq [string]$recDish.description)
    $ingredientNamesMatchMenu = ((@((Unwrap-Collection $menuMatch.ingredients) | ForEach-Object { $_.name }) -join '|') -eq (@($ingredientNames) -join '|'))
}
$normalDish = @($menuDishes | Where-Object { $_.available -eq $true -and (Unwrap-Collection $_.ingredients).Count -gt 0 } | Select-Object -First 1)[0]
if ($null -eq $normalDish) { $normalDish = @($menuDishes | Where-Object { $_.available -eq $true } | Select-Object -First 1)[0] }
$addItem = Invoke-RestApi -Method POST -Url "$base/api/gateway/customer/order/items" -Session $customerSession -Body @{ dishId = [int]$normalDish.dishId; quantity = 1 }
$orderItems = Invoke-RestApi -Url "$base/api/gateway/customer/order/items" -Session $customerSession
$itemId = $null
if ($orderItems.ok -and @((Unwrap-Collection $orderItems.json.items)).Count -gt 0) { $itemId = [int](@((Unwrap-Collection $orderItems.json.items))[0]).itemId }
$removeItem = $null
if ($itemId) { $removeItem = Invoke-RestApi -Method DELETE -Url "$base/api/gateway/customer/order/items/$itemId" -Session $customerSession }
$indexHtml = Invoke-WebRequest -Uri "$base/" -UseBasicParsing
$assetMatch = [regex]::Match([string]$indexHtml.Content, '/assets/[^"'']+\.js')
$assetContainsDetailText = $false
if ($assetMatch.Success) {
    $assetResp = Invoke-WebRequest -Uri "$base$($assetMatch.Value)" -UseBasicParsing
    $assetContainsDetailText = ([string]$assetResp.Content -match 'Chi tiết món')
}
$report.Task1 = [ordered]@{
    loginStatus = $customerLogin.status
    tableContext = @{ branchId = $branchId; tableId = $tableId; tableNumber = $tableNumber }
    recommendationCount = @($recommended).Count
    recommendationSample = $recDish
    recommendationHasIngredients = ($null -ne $recDish -and $null -ne $recDish.ingredients -and $recDish.ingredients.Count -gt 0)
    recommendationIngredientNames = @($ingredientNames)
    recommendationDescriptionMatchesMenu = $descMatchesMenu
    recommendationIngredientsMatchMenu = $ingredientNamesMatchMenu
    runtimeAssetContainsDetailText = $assetContainsDetailText
    normalDishSample = $normalDish
    addItemResponse = $addItem
    orderItemsAfterAdd = $orderItems
    removeItemResponse = $removeItem
}

# Task 2
$adminLogin = Invoke-RestApi -Method POST -Url "$base/api/gateway/admin/auth/login" -Session $adminSession -Body @{ username = 'admin'; password = '123456' }
if (-not $adminLogin.ok) { throw "Admin login failed: $($adminLogin.raw)" }
function Get-Ingredients($session, [string]$search = '') {
    $query = if ([string]::IsNullOrWhiteSpace($search)) { '' } else { [Uri]::EscapeDataString($search) }
    return Invoke-RestApi -Url "$base/api/gateway/admin/ingredients?search=$query&page=1&pageSize=20" -Session $session
}
$createName = 'ING_RT_' + [DateTime]::Now.ToString('yyyyMMddHHmmssfff')
$createResp = Invoke-RestApi -Method POST -Url "$base/api/gateway/admin/ingredients" -Session $adminSession -Body @{ name = $createName; unit = 'kg'; currentStock = 12; reorderLevel = 3; isActive = $true }
$afterCreate = Get-Ingredients $adminSession $createName
$createdItem = @((Unwrap-Collection $afterCreate.json.ingredients.items) | Where-Object { $_.name -eq $createName } | Select-Object -First 1)[0]
$createdId = [int]$createdItem.ingredientId
$editName = $createName + '_EDIT'
$editResp = Invoke-RestApi -Method PUT -Url "$base/api/gateway/admin/ingredients/$createdId" -Session $adminSession -Body @{ name = $editName; unit = 'gram'; currentStock = 25; reorderLevel = 5; isActive = $true }
$afterEdit = Get-Ingredients $adminSession $editName
$editedItem = @((Unwrap-Collection $afterEdit.json.ingredients.items) | Where-Object { [int]$_.ingredientId -eq $createdId } | Select-Object -First 1)[0]
$disableResp = Invoke-RestApi -Method POST -Url "$base/api/gateway/admin/ingredients/$createdId/deactivate" -Session $adminSession -Body @{}
$afterDisable = Get-Ingredients $adminSession $editName
$disabledItem = @((Unwrap-Collection $afterDisable.json.ingredients.items) | Where-Object { [int]$_.ingredientId -eq $createdId } | Select-Object -First 1)[0]
$deleteName = 'ING_DEL_' + [DateTime]::Now.ToString('yyyyMMddHHmmssfff')
$createDeleteResp = Invoke-RestApi -Method POST -Url "$base/api/gateway/admin/ingredients" -Session $adminSession -Body @{ name = $deleteName; unit = 'lit'; currentStock = 7; reorderLevel = 2; isActive = $true }
$afterCreateDelete = Get-Ingredients $adminSession $deleteName
$deleteItem = @((Unwrap-Collection $afterCreateDelete.json.ingredients.items) | Where-Object { $_.name -eq $deleteName } | Select-Object -First 1)[0]
$deleteId = [int]$deleteItem.ingredientId
$deleteResp = Invoke-RestApi -Method DELETE -Url "$base/api/gateway/admin/ingredients/$deleteId" -Session $adminSession
$afterDelete = Get-Ingredients $adminSession $deleteName
$deletedStillExists = @((Unwrap-Collection $afterDelete.json.ingredients.items) | Where-Object { [int]$_.ingredientId -eq $deleteId }).Count -gt 0
$dishes = Invoke-RestApi -Url "$base/api/gateway/admin/dishes?search=&page=1&pageSize=10" -Session $adminSession
$firstDish = @((Unwrap-Collection $dishes.json.dishes.items) | Select-Object -First 1)[0]
$dishIngredients = Invoke-RestApi -Url "$base/api/gateway/admin/dishes/$($firstDish.dishId)/ingredients" -Session $adminSession
$linkedIngredient = @((Unwrap-Collection $dishIngredients.json) | Where-Object { $_.selected -eq $true } | Select-Object -First 1)[0]
$conflictDelete = Invoke-RestApi -Method DELETE -Url "$base/api/gateway/admin/ingredients/$($linkedIngredient.ingredientId)" -Session $adminSession
$adminPage = Invoke-WebRequest -Uri "$base/app/admin/Admin/Ingredients/Index" -UseBasicParsing -WebSession $adminSession
$report.Task2 = [ordered]@{
    loginStatus = $adminLogin.status
    createResponse = $createResp
    createdAppearsInList = ($null -ne $createdItem)
    editResponse = $editResp
    editedListItem = $editedItem
    disableResponse = $disableResp
    disabledListItem = $disabledItem
    deleteResponse = $deleteResp
    deletedStillExistsInList = $deletedStillExists
    referencedIngredient = $linkedIngredient
    referencedDeleteResponse = $conflictDelete
    runtimeAdminPageStatus = [int]$adminPage.StatusCode
}

$report | ConvertTo-Json -Depth 20
