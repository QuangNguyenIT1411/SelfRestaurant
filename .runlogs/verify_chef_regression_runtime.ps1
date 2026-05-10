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
    if ($null -ne $Body) { $params.ContentType = 'application/json'; $params.Body = ($Body | ConvertTo-Json -Depth 20) }
    try {
        $json = Invoke-RestMethod @params
        return [pscustomobject]@{ ok = $true; status = 200; json = $json; raw = ($json | ConvertTo-Json -Depth 20 -Compress) }
    } catch {
        $err = Read-ErrorResponse $_.Exception
        return [pscustomobject]@{ ok = $false; status = $err.status; json = $err.json; raw = $err.raw }
    }
}

$base = 'http://localhost:5100'
$customerSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$chefSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$report = [ordered]@{}
$tableId = $null

try {
    $chefLogin = Invoke-RestApi -Method POST -Url "$base/api/gateway/staff/auth/login" -Session $chefSession -Body @{ username = 'chef_hung'; password = '123456' }
    if (-not $chefLogin.ok) { throw "Chef login failed: $($chefLogin.raw)" }
    $branchId = [int]$chefLogin.json.session.staff.branchId
    $dashboard0 = Invoke-RestApi -Url "$base/api/gateway/staff/chef/dashboard" -Session $chefSession
    $chefMenu = Invoke-RestApi -Url "$base/api/gateway/staff/chef/menu" -Session $chefSession
    $targetDish = @($chefMenu.json.dishes | Select-Object -First 1)[0]
    $ingredientsGet = Invoke-RestApi -Url "$base/api/gateway/staff/chef/dishes/$($targetDish.dishId)/ingredients" -Session $chefSession
    $ingredientsPayload = @($ingredientsGet.json.items | ForEach-Object {
        [ordered]@{
            ingredientId = [int]$_.ingredientId
            quantityPerDish = [decimal]$_.quantityPerDish
        }
    })
    $ingredientsSave = Invoke-RestApi -Method PUT -Url "$base/api/gateway/staff/chef/dishes/$($targetDish.dishId)/ingredients" -Session $chefSession -Body @{ items = $ingredientsPayload }

    $customerLogin = Invoke-RestApi -Method POST -Url "$base/api/gateway/customer/auth/login" -Session $customerSession -Body @{ username = 'lan.nguyen'; password = '123456' }
    if (-not $customerLogin.ok) { throw "Customer login failed: $($customerLogin.raw)" }
    $tables = Invoke-RestApi -Url "$base/api/gateway/customer/branches/$branchId/tables" -Session $customerSession
    $table = @($tables.json.tables | Where-Object { $_.isAvailable -eq $true } | Select-Object -First 1)
    if ($table.Count -eq 0) { $table = @($tables.json.tables | Select-Object -First 1) }
    $tableId = [int]$table[0].tableId
    $setContext = Invoke-RestApi -Method POST -Url "$base/api/gateway/customer/context/table" -Session $customerSession -Body @{ tableId = $tableId; branchId = $branchId }
    $menu = Invoke-RestApi -Url "$base/api/gateway/customer/menu" -Session $customerSession
    $availableDishes = @()
    foreach ($category in @($menu.json.menu.categories)) {
        foreach ($dish in @($category.dishes | Where-Object { $_.available -eq $true })) {
            $availableDishes += $dish
        }
    }
    if ($availableDishes.Count -lt 2) { throw 'Not enough available dishes for chef regression test.' }

    $noteA = 'CHEF_REG_START_' + [DateTime]::UtcNow.ToString('yyyyMMddHHmmss')
    $noteB = 'CHEF_REG_CANCEL_' + [DateTime]::UtcNow.ToString('yyyyMMddHHmmss')
    [void](Invoke-RestApi -Method POST -Url "$base/api/gateway/customer/order/items" -Session $customerSession -Body @{ dishId = [int]$availableDishes[0].dishId; quantity = 1; note = $noteA })
    [void](Invoke-RestApi -Method POST -Url "$base/api/gateway/customer/order/items" -Session $customerSession -Body @{ dishId = [int]$availableDishes[1].dishId; quantity = 1; note = $noteB })
    $orderBeforeSubmit = Invoke-RestApi -Url "$base/api/gateway/customer/order" -Session $customerSession
    $orderId = [int]$orderBeforeSubmit.json.orderId
    $submit = Invoke-RestApi -Method POST -Url "$base/api/gateway/customer/order/submit" -Session $customerSession -Body @{ idempotencyKey = [guid]::NewGuid().ToString('N'); expectedDiningSessionCode = $null }
    $dashboard1 = Invoke-RestApi -Url "$base/api/gateway/staff/chef/dashboard" -Session $chefSession
    $pendingOrder = @($dashboard1.json.pendingOrders | Where-Object { [int]$_.orderId -eq $orderId } | Select-Object -First 1)[0]
    if ($null -eq $pendingOrder) { throw "Pending chef order $orderId not found." }
    $itemA = @($pendingOrder.items | Where-Object { $_.note -like "*$noteA*" } | Select-Object -First 1)[0]
    $itemB = @($pendingOrder.items | Where-Object { $_.note -like "*$noteB*" } | Select-Object -First 1)[0]
    $patchNote = Invoke-RestApi -Method PATCH -Url "$base/api/gateway/staff/chef/orders/$orderId/items/$($itemA.itemId)/note" -Session $chefSession -Body @{ note = ' | checked'; append = $true }
    $startItem = Invoke-RestApi -Method POST -Url "$base/api/gateway/staff/chef/orders/$orderId/items/$($itemA.itemId)/start" -Session $chefSession -Body @{}
    $readyItem = Invoke-RestApi -Method POST -Url "$base/api/gateway/staff/chef/orders/$orderId/items/$($itemA.itemId)/ready" -Session $chefSession -Body @{}
    $cancelItem = Invoke-RestApi -Method POST -Url "$base/api/gateway/staff/chef/orders/$orderId/items/$($itemB.itemId)/cancel" -Session $chefSession -Body @{ reason = 'Regression cancel test' }
    $dashboard2 = Invoke-RestApi -Url "$base/api/gateway/staff/chef/dashboard" -Session $chefSession
    $readyOrder = @($dashboard2.json.readyOrders | Where-Object { [int]$_.orderId -eq $orderId } | Select-Object -First 1)[0]
    $history = Invoke-RestApi -Url "$base/api/gateway/staff/chef/history?take=20" -Session $chefSession
    $repeatStart = Invoke-RestApi -Method POST -Url "$base/api/gateway/staff/chef/orders/$orderId/items/$($itemA.itemId)/start" -Session $chefSession -Body @{}

    $chefPage = Invoke-WebRequest -Uri "$base/app/chef/Staff/Chef/Index" -UseBasicParsing -WebSession $chefSession -TimeoutSec 60
    $appAssetMatch = [regex]::Match([string]$chefPage.Content, '/app/chef/assets/index-[^"'']+\.js')
    $assetText = ''
    $assetUrl = $null
    if ($appAssetMatch.Success) {
        $assetUrl = "$base$($appAssetMatch.Value)"
        $assetText = [string](Invoke-WebRequest -Uri $assetUrl -UseBasicParsing -WebSession $chefSession -TimeoutSec 60).Content
    }

    $report = [ordered]@{
        chefLoginStatus = $chefLogin.status
        dashboardStatus = $dashboard0.status
        chefMenuStatus = $chefMenu.status
        dishIngredientLoadOk = $ingredientsGet.ok
        dishIngredientSaveOk = $ingredientsSave.ok
        customerOrder = [ordered]@{
            orderId = $orderId
            submitOk = $submit.ok
            noteVisibleOnChefOrder = ($null -ne $itemA -and $null -ne $itemB)
        }
        itemActions = [ordered]@{
            patchNoteOk = $patchNote.ok
            startItemOk = $startItem.ok
            readyItemOk = $readyItem.ok
            cancelItemOk = $cancelItem.ok
            readyOrderFoundAfterActions = ($null -ne $readyOrder)
            readyOrderItemStatuses = if ($null -ne $readyOrder) { @($readyOrder.items | Select-Object itemId, statusCode, note) } else { @() }
            historyContainsOrder = (@($history.json | Where-Object { [int]$_.orderId -eq $orderId }).Count -gt 0)
        }
        startAgainPath = [ordered]@{
            ok = $repeatStart.ok
            status = $repeatStart.status
            raw = $repeatStart.raw
        }
        ui = [ordered]@{
            pageStatus = [int]$chefPage.StatusCode
            assetUrl = $assetUrl
            hasIngredientEditorText = ($assetText -match 'thành phần|thanh phan')
            hasCustomerNoteText = ($assetText -match 'ghi chú khách|ghi chu khach|ghi chú')
        }
    }
}
finally {
    if ($null -ne $tableId -and $tableId -gt 0) {
        try { [void](Invoke-RestApi -Method POST -Url "$base/api/gateway/customer/context/table/reset" -Session $customerSession) } catch {}
    }
}

$report | ConvertTo-Json -Depth 10
