$ErrorActionPreference = 'Stop'

$base = 'http://localhost:5100'
$customerBase = "$base/api/gateway/customer"
$staffBase = "$base/api/gateway/staff"
$summaryPath = 'C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main\.runlogs\gateway_api_chef_smoke_summary.json'

function Invoke-JsonGet {
    param([string]$Uri, [Microsoft.PowerShell.Commands.WebRequestSession]$Session)
    try {
        Write-Host "GET $Uri"
        Invoke-RestMethod -Method Get -Uri $Uri -WebSession $Session -TimeoutSec 60
    }
    catch {
        $response = $_.Exception.Response
        if ($response -and $response.GetResponseStream()) {
            $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
            $body = $reader.ReadToEnd()
            throw "GET $Uri failed: $body"
        }
        throw
    }
}

function Invoke-JsonSend {
    param(
        [ValidateSet('Post','Put','Patch','Delete')][string]$Method,
        [string]$Uri,
        [object]$Body,
        [Microsoft.PowerShell.Commands.WebRequestSession]$Session
    )

    try {
        Write-Host "$Method $Uri"
        if ($null -eq $Body) {
            Invoke-RestMethod -Method $Method -Uri $Uri -WebSession $Session -TimeoutSec 60
        }
        else {
            $json = $Body | ConvertTo-Json -Depth 20
            Invoke-RestMethod -Method $Method -Uri $Uri -WebSession $Session -TimeoutSec 60 -ContentType 'application/json' -Body $json
        }
    }
    catch {
        $response = $_.Exception.Response
        if ($response -and $response.GetResponseStream()) {
            $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
            $body = $reader.ReadToEnd()
            throw "$Method $Uri failed: $body"
        }
        throw
    }
}

$customerSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$staffSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession

$chefLogin = Invoke-JsonSend Post "$staffBase/auth/login" @{ username = 'chef_hung'; password = '123456' } $staffSession
$branchId = [int]$chefLogin.session.staff.branchId

$tablesResponse = Invoke-JsonGet "$customerBase/branches/$branchId/tables" $customerSession
if (-not $tablesResponse.tables -or $tablesResponse.tables.Count -eq 0) {
    throw "No tables found for branch $branchId"
}
$table = $tablesResponse.tables | Where-Object { $_.statusCode -ne 'OCCUPIED' } | Select-Object -First 1
if ($null -eq $table) {
    $table = $tablesResponse.tables | Select-Object -First 1
}
[void](Invoke-JsonSend Post "$customerBase/context/table" @{ tableId = [int]$table.tableId; branchId = $branchId } $customerSession)

$stamp = [DateTime]::UtcNow.ToString('yyyyMMddHHmmss')
$username = "chef_api_$stamp"
$password = '123456'
$phone = '09' + $stamp.Substring($stamp.Length - 8)
[void](Invoke-JsonSend Post "$customerBase/auth/register" @{
    name = "Chef Api $stamp"
    username = $username
    password = $password
    phoneNumber = $phone
    email = "$username@example.com"
} $customerSession)
[void](Invoke-JsonSend Post "$customerBase/auth/login" @{ username = $username; password = $password } $customerSession)

$menuResponse = Invoke-JsonGet "$customerBase/menu" $customerSession
$dish = $null
foreach ($category in $menuResponse.menu.categories) {
    foreach ($candidate in $category.dishes) {
        if ($candidate.available) {
            $dish = $candidate
            break
        }
    }
    if ($null -ne $dish) { break }
}
if ($null -eq $dish) {
    throw "No available dishes found in branch $branchId menu"
}

[void](Invoke-JsonSend Post "$customerBase/order/items" @{ dishId = [int]$dish.dishId; quantity = 1; note = 'chef api smoke' } $customerSession)
$orderBeforeSubmit = Invoke-JsonGet "$customerBase/order" $customerSession
$orderId = [int]$orderBeforeSubmit.orderId
$itemId = [int]$orderBeforeSubmit.items[0].itemId
[void](Invoke-JsonSend Post "$customerBase/order/submit" $null $customerSession)

$dashboard = Invoke-JsonGet "$staffBase/chef/dashboard" $staffSession
$pendingIds = @($dashboard.pendingOrders | ForEach-Object { [int]$_.orderId })
if ($pendingIds -notcontains $orderId) {
    throw "Submitted order $orderId not visible in chef pending list: $($pendingIds -join ',')"
}

[void](Invoke-JsonSend Patch "$staffBase/chef/orders/$orderId/items/$itemId/note" @{ note = 'checked by api chef'; append = $true } $staffSession)
[void](Invoke-JsonSend Post "$staffBase/chef/orders/$orderId/start" $null $staffSession)
[void](Invoke-JsonSend Post "$staffBase/chef/orders/$orderId/ready" $null $staffSession)
[void](Invoke-JsonSend Post "$staffBase/chef/orders/$orderId/serve" $null $staffSession)

$chefMenu = Invoke-JsonGet "$staffBase/chef/menu" $staffSession
$targetDish = $chefMenu.dishes | Where-Object { [int]$_.dishId -eq [int]$dish.dishId } | Select-Object -First 1
if ($null -eq $targetDish) {
    $targetDish = $chefMenu.dishes | Select-Object -First 1
}
if ($null -eq $targetDish) {
    throw 'Chef menu is empty'
}

$ingredients = Invoke-JsonGet "$staffBase/chef/dishes/$($targetDish.dishId)/ingredients" $staffSession
if ($ingredients.items -and $ingredients.items.Count -gt 0) {
    $ingredientPayload = @($ingredients.items | ForEach-Object {
        [ordered]@{
            ingredientId = [int]$_.ingredientId
            name = [string]$_.name
            unit = [string]$_.unit
            currentStock = [decimal]$_.currentStock
            isActive = [bool]$_.isActive
            quantityPerDish = [decimal]$_.quantityPerDish
        }
    })
    [void](Invoke-JsonSend Put "$staffBase/chef/dishes/$($targetDish.dishId)/ingredients" @{ items = $ingredientPayload } $staffSession)
}
$originalAvailable = [bool]$targetDish.available
[void](Invoke-JsonSend Post "$staffBase/chef/dishes/$($targetDish.dishId)/availability" @{ available = (-not $originalAvailable) } $staffSession)
[void](Invoke-JsonSend Post "$staffBase/chef/dishes/$($targetDish.dishId)/availability" @{ available = $originalAvailable } $staffSession)

$history = Invoke-JsonGet "$staffBase/chef/history?take=20" $staffSession
$historyIds = @($history | ForEach-Object { [int]$_.orderId })

$summary = [ordered]@{
    success = $true
    branchId = $branchId
    orderId = $orderId
    itemId = $itemId
    dishId = [int]$targetDish.dishId
    historyContainsOrder = ($historyIds -contains $orderId)
    timestampUtc = [DateTime]::UtcNow.ToString('o')
}
$summary | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
Write-Host "PASS order=$orderId dish=$($targetDish.dishId) branch=$branchId"
