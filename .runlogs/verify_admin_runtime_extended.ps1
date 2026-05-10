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
    $params = @{ Uri = $Url; Method = $Method; TimeoutSec = 60; UseBasicParsing = $true }
    if ($null -ne $Session) { $params.WebSession = $Session }
    if ($null -ne $Body) {
        $params.ContentType = 'application/json'
        $params.Body = ($Body | ConvertTo-Json -Depth 20)
    }
    try {
        $resp = Invoke-WebRequest @params
        $json = if ([string]::IsNullOrWhiteSpace($resp.Content)) { $null } else { $resp.Content | ConvertFrom-Json }
        return [pscustomobject]@{ ok = $true; status = [int]$resp.StatusCode; json = $json; raw = [string]$resp.Content }
    } catch {
        $err = Read-ErrorResponse $_.Exception
        return [pscustomobject]@{ ok = $false; status = $err.status; json = $err.json; raw = $err.raw }
    }
}

$base = 'http://localhost:5100'
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$stamp = [DateTime]::UtcNow.ToString('yyyyMMddHHmmss')

$login = Invoke-RestApi -Method POST -Url "$base/api/gateway/admin/auth/login" -Session $session -Body @{ username = 'admin'; password = '123456' }
if (-not $login.ok) { throw "Admin login failed: $($login.raw)" }

$ingredientsPage1 = Invoke-RestApi -Url "$base/api/gateway/admin/ingredients?search=&page=1&pageSize=2&includeInactive=true" -Session $session
$ingredientsPage2 = Invoke-RestApi -Url "$base/api/gateway/admin/ingredients?search=&page=2&pageSize=2&includeInactive=true" -Session $session
$createName = "ING_EXT_$stamp"
$createResp = Invoke-RestApi -Method POST -Url "$base/api/gateway/admin/ingredients" -Session $session -Body @{ name = $createName; unit = 'kg'; currentStock = 9; reorderLevel = 2; isActive = $true }
$createdList = Invoke-RestApi -Url "$base/api/gateway/admin/ingredients?search=$createName&page=1&pageSize=10&includeInactive=true" -Session $session
$createdItem = @($createdList.json.ingredients.items | Where-Object { $_.name -eq $createName } | Select-Object -First 1)[0]
$createdId = [int]$createdItem.ingredientId
$editName = "${createName}_EDIT"
$editResp = Invoke-RestApi -Method PUT -Url "$base/api/gateway/admin/ingredients/$createdId" -Session $session -Body @{ name = $editName; unit = 'gram'; currentStock = 11; reorderLevel = 3; isActive = $true }
$disableResp = Invoke-RestApi -Method POST -Url "$base/api/gateway/admin/ingredients/$createdId/deactivate" -Session $session -Body @{}
$inactiveSearch = Invoke-RestApi -Url "$base/api/gateway/admin/ingredients?search=$editName&page=1&pageSize=10&includeInactive=false" -Session $session
$inactiveSearchWithFlag = Invoke-RestApi -Url "$base/api/gateway/admin/ingredients?search=$editName&page=1&pageSize=10&includeInactive=true" -Session $session
$deleteName = "ING_DEL_EXT_$stamp"
$createDelete = Invoke-RestApi -Method POST -Url "$base/api/gateway/admin/ingredients" -Session $session -Body @{ name = $deleteName; unit = 'lit'; currentStock = 5; reorderLevel = 1; isActive = $true }
$deleteList = Invoke-RestApi -Url "$base/api/gateway/admin/ingredients?search=$deleteName&page=1&pageSize=10&includeInactive=true" -Session $session
$deleteItem = @($deleteList.json.ingredients.items | Where-Object { $_.name -eq $deleteName } | Select-Object -First 1)[0]
$deleteResp = Invoke-RestApi -Method DELETE -Url "$base/api/gateway/admin/ingredients/$($deleteItem.ingredientId)" -Session $session

$dishesPage1 = Invoke-RestApi -Url "$base/api/gateway/admin/dishes?search=&page=1&pageSize=2&includeInactive=true" -Session $session
$dishesPage2 = Invoke-RestApi -Url "$base/api/gateway/admin/dishes?search=&page=2&pageSize=2&includeInactive=true" -Session $session
$vegDishes = Invoke-RestApi -Url "$base/api/gateway/admin/dishes?search=&page=1&pageSize=20&includeInactive=true&vegetarianOnly=true" -Session $session
$categoryId = [int](@($dishesPage1.json.categories | Select-Object -First 1)[0].categoryId)
$dishName = "DISH_EXT_$stamp"
$createDish = Invoke-RestApi -Method POST -Url "$base/api/gateway/admin/dishes" -Session $session -Body @{
    name = $dishName
    price = 55000
    categoryId = $categoryId
    description = 'dish ext'
    unit = 'Phần'
    image = '/images/placeholder-dish.svg'
    isVegetarian = $false
    isDailySpecial = $false
    available = $true
    isActive = $true
}
$dishSearch = Invoke-RestApi -Url "$base/api/gateway/admin/dishes?search=$dishName&page=1&pageSize=10&includeInactive=true" -Session $session
$createdDish = @($dishSearch.json.dishes.items | Where-Object { $_.name -eq $dishName } | Select-Object -First 1)[0]
$dishId = [int]$createdDish.dishId
$updateDish = Invoke-RestApi -Method PUT -Url "$base/api/gateway/admin/dishes/$dishId" -Session $session -Body @{
    name = "${dishName}_EDIT"
    price = 57000
    categoryId = $categoryId
    description = 'dish ext edit'
    unit = 'Tô'
    image = '/images/placeholder-dish.svg'
    isVegetarian = $false
    isDailySpecial = $false
    available = $true
    isActive = $true
}
$deactivateDish = Invoke-RestApi -Method POST -Url "$base/api/gateway/admin/dishes/$dishId/deactivate" -Session $session -Body @{}

$tablesPage1 = Invoke-RestApi -Url "$base/api/gateway/admin/tables?search=&page=1&pageSize=2" -Session $session
$tablesPage2 = Invoke-RestApi -Url "$base/api/gateway/admin/tables?search=&page=2&pageSize=2" -Session $session
$tableSearch = Invoke-RestApi -Url "$base/api/gateway/admin/tables?search=Chi%20nhánh&page=1&pageSize=20" -Session $session

$employees = Invoke-WebRequest -Uri "$base/app/admin/Admin/Employees/Index" -WebSession $session -UseBasicParsing -TimeoutSec 60
$customers = Invoke-WebRequest -Uri "$base/app/admin/Admin/Customers/Index" -WebSession $session -UseBasicParsing -TimeoutSec 60
$ingredientsPage = Invoke-WebRequest -Uri "$base/app/admin/Admin/Ingredients/Index" -WebSession $session -UseBasicParsing -TimeoutSec 60
$assetMatch = [regex]::Match([string]$ingredientsPage.Content, '/app/admin/assets/index-[^"]+\.js')
$cssMatch = [regex]::Match([string]$ingredientsPage.Content, '/app/admin/assets/index-[^"]+\.css')
$jsText = if ($assetMatch.Success) { [string](Invoke-WebRequest -Uri "$base$($assetMatch.Value)" -WebSession $session -UseBasicParsing -TimeoutSec 60).Content } else { '' }
$cssText = if ($cssMatch.Success) { [string](Invoke-WebRequest -Uri "$base$($cssMatch.Value)" -WebSession $session -UseBasicParsing -TimeoutSec 60).Content } else { '' }

$result = [ordered]@{
    loginStatus = $login.status
    localization = [ordered]@{
        ingredientCreateMessage = $createResp.json.message
        ingredientConflictMessage = $null
        bundleLoaded = (-not [string]::IsNullOrWhiteSpace($jsText))
    }
    ingredients = [ordered]@{
        page1Ids = @($ingredientsPage1.json.ingredients.items | ForEach-Object { [int]$_.ingredientId })
        page2Ids = @($ingredientsPage2.json.ingredients.items | ForEach-Object { [int]$_.ingredientId })
        createdId = $createdId
        createOk = $createResp.ok
        editOk = $editResp.ok
        disableOk = $disableResp.ok
        deleteOk = $deleteResp.ok
        hiddenWhenInactiveExcluded = (@($inactiveSearch.json.ingredients.items).Count -eq 0)
        shownWhenInactiveIncluded = (@($inactiveSearchWithFlag.json.ingredients.items).Count -gt 0)
    }
    dishes = [ordered]@{
        page1Ids = @($dishesPage1.json.dishes.items | ForEach-Object { [int]$_.dishId })
        page2Ids = @($dishesPage2.json.dishes.items | ForEach-Object { [int]$_.dishId })
        vegetarianOnlyCount = @($vegDishes.json.dishes.items).Count
        vegetarianOnlyAllTrue = (@($vegDishes.json.dishes.items | Where-Object { $_.isVegetarian -ne $true }).Count -eq 0)
        createOk = $createDish.ok
        updateOk = $updateDish.ok
        deactivateOk = $deactivateDish.ok
    }
    tables = [ordered]@{
        page1Ids = @($tablesPage1.json.tables.items | ForEach-Object { [int]$_.tableId })
        page2Ids = @($tablesPage2.json.tables.items | ForEach-Object { [int]$_.tableId })
        searchCount = @($tableSearch.json.tables.items).Count
    }
    pages = [ordered]@{
        employeesStatus = [int]$employees.StatusCode
        customersStatus = [int]$customers.StatusCode
        ingredientsStatus = [int]$ingredientsPage.StatusCode
    }
    layout = [ordered]@{
        cssHas252Sidebar = ($cssText -match '252px')
        cssHasTighterShellPadding = ($cssText -match 'padding:\s*24px 28px')
    }
}

try {
    $firstDish = @($dishesPage1.json.dishes.items | Select-Object -First 1)[0]
    $linkedIngredient = Invoke-RestApi -Url "$base/api/gateway/admin/dishes/$($firstDish.dishId)/ingredients" -Session $session
    $selectedLinked = @($linkedIngredient.json | Where-Object { $_.selected -eq $true } | Select-Object -First 1)[0]
    if ($null -ne $selectedLinked) {
        $conflict = Invoke-RestApi -Method DELETE -Url "$base/api/gateway/admin/ingredients/$($selectedLinked.ingredientId)" -Session $session
        $result.localization.ingredientConflictMessage = $conflict.json.message
        $result.ingredients | Add-Member -NotePropertyName referencedDeleteStatus -NotePropertyValue $conflict.status -Force
    }
}
catch {}

$result | ConvertTo-Json -Depth 12
