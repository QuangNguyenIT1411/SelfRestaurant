$ErrorActionPreference = 'Stop'

$base = 'http://localhost:5100'
$catalog = 'http://localhost:5101'
$orders = 'http://localhost:5102'
$billing = 'http://localhost:5105'
$cashierBase = "$base/api/gateway/staff/cashier"
$cashierSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession

function Invoke-Json {
    param(
        [ValidateSet('GET', 'POST', 'PUT', 'PATCH', 'DELETE')][string]$Method,
        [string]$Uri,
        [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession = $null,
        $Body = $null
    )

    try {
        if ($null -eq $Body) {
            if ($null -eq $WebSession) {
                return Invoke-RestMethod -Method $Method -Uri $Uri -TimeoutSec 60
            }

            return Invoke-RestMethod -Method $Method -Uri $Uri -WebSession $WebSession -TimeoutSec 60
        }

        $json = $Body | ConvertTo-Json -Depth 20
        $payload = [System.Text.Encoding]::UTF8.GetBytes($json)
        if ($null -eq $WebSession) {
            return Invoke-RestMethod -Method $Method -Uri $Uri -TimeoutSec 60 -ContentType 'application/json; charset=utf-8' -Body $payload
        }

        return Invoke-RestMethod -Method $Method -Uri $Uri -WebSession $WebSession -TimeoutSec 60 -ContentType 'application/json; charset=utf-8' -Body $payload
    }
    catch {
        $response = $_.Exception.Response
        if ($response -and $response.GetResponseStream()) {
            $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
            throw $reader.ReadToEnd()
        }

        throw
    }
}

function Build-TransferReference([string]$OrderCode, [int]$OrderId) {
    $code = ''
    if ($null -ne $OrderCode) {
        $code = $OrderCode.Trim()
    }
    if ($code) {
        return ("TT $code").Substring(0, [Math]::Min(("TT $code").Length, 40))
    }

    return ("TT ORD$OrderId").Substring(0, [Math]::Min(("TT ORD$OrderId").Length, 40))
}

function Build-QrUrl([decimal]$Amount, [string]$OrderCode, [int]$OrderId) {
    $rounded = [Math]::Max(0, [int][Math]::Round($Amount, 0))
    $reference = [Uri]::EscapeDataString((Build-TransferReference $OrderCode $OrderId))
    return "https://img.vietqr.io/image/BIDV-8830150124-compact2.png?amount=$rounded&addInfo=$reference"
}

function Find-AvailableTable([int]$BranchId, [int[]]$ExcludeTableIds) {
    $tables = Invoke-Json GET "$catalog/api/branches/$BranchId/tables"
    $table = $tables.tables | Where-Object { $_.isAvailable -and $ExcludeTableIds -notcontains [int]$_.tableId } | Select-Object -First 1
    if ($null -eq $table) {
        $table = $tables.tables | Where-Object { $ExcludeTableIds -notcontains [int]$_.tableId } | Select-Object -First 1
    }

    if ($null -eq $table) {
        throw "No test table available for branch $BranchId"
    }

    return $table
}

function New-TestOrder([int]$BranchId, [int]$DishId, [int]$Quantity, [string]$Note, [int[]]$ExcludeTableIds) {
    $table = Find-AvailableTable $BranchId $ExcludeTableIds
    $tableId = [int]$table.tableId
    Invoke-Json POST "$orders/api/tables/$tableId/reset" $null @{} | Out-Null
    Invoke-Json POST "$orders/api/tables/$tableId/order/items" $null @{
        dishId = $DishId
        quantity = $Quantity
        note = $Note
    } | Out-Null
    Invoke-Json POST "$orders/api/tables/$tableId/order/submit" $null @{
        idempotencyKey = [guid]::NewGuid().ToString('N')
        expectedDiningSessionCode = $null
    } | Out-Null

    $active = Invoke-Json GET "$orders/api/tables/$tableId/order"
    return [pscustomobject]@{
        TableId = $tableId
        OrderId = [int]$active.orderId
    }
}

$login = Invoke-Json POST "$cashierBase/auth/login" $cashierSession @{
    username = 'cashier_lan'
    password = '123456'
}

$branchId = [int]$login.session.staff.branchId
$dashboard = Invoke-Json GET "$cashierBase/dashboard" $cashierSession
$menu = Invoke-Json GET "$catalog/api/branches/$branchId/menu"
$dish = $null
foreach ($category in @($menu.categories)) {
    $dish = @($category.dishes | Where-Object { $_.available }) | Select-Object -First 1
    if ($dish) { break }
}

if ($null -eq $dish) {
    throw "No available dish found for branch $branchId"
}

$dishId = [int]$dish.dishId
$usedTables = @()
$qrOrderA = New-TestOrder -BranchId $branchId -DishId $dishId -Quantity 1 -Note 'qr-runtime-a' -ExcludeTableIds $usedTables
$usedTables += $qrOrderA.TableId
$qrOrderB = New-TestOrder -BranchId $branchId -DishId $dishId -Quantity 2 -Note 'qr-runtime-b' -ExcludeTableIds $usedTables
$usedTables += $qrOrderB.TableId
$cashOrder = New-TestOrder -BranchId $branchId -DishId $dishId -Quantity 1 -Note 'cash-runtime' -ExcludeTableIds $usedTables

$dashboardAfter = Invoke-Json GET "$cashierBase/dashboard" $cashierSession
$dashboardOrderA = $dashboardAfter.orders | Where-Object { [int]$_.orderId -eq $qrOrderA.OrderId } | Select-Object -First 1
$dashboardOrderB = $dashboardAfter.orders | Where-Object { [int]$_.orderId -eq $qrOrderB.OrderId } | Select-Object -First 1
$dashboardCashOrder = $dashboardAfter.orders | Where-Object { [int]$_.orderId -eq $cashOrder.OrderId } | Select-Object -First 1

if ($null -eq $dashboardOrderA -or $null -eq $dashboardOrderB -or $null -eq $dashboardCashOrder) {
    throw "One or more runtime test orders did not appear in cashier dashboard."
}

$transferReferenceA = Build-TransferReference ([string]$dashboardOrderA.orderCode) ([int]$dashboardOrderA.orderId)
$transferReferenceB = Build-TransferReference ([string]$dashboardOrderB.orderCode) ([int]$dashboardOrderB.orderId)
$qrUrlA = Build-QrUrl ([decimal]$dashboardOrderA.subtotal) ([string]$dashboardOrderA.orderCode) ([int]$dashboardOrderA.orderId)
$qrUrlB = Build-QrUrl ([decimal]$dashboardOrderB.subtotal) ([string]$dashboardOrderB.orderCode) ([int]$dashboardOrderB.orderId)

$qrHead = Invoke-WebRequest -Uri $qrUrlA -TimeoutSec 60 -UseBasicParsing
$checkoutStateBefore = Invoke-Json GET "$billing/api/internal/checkout-state?orderId=$($dashboardOrderA.orderId)"

$cashCheckout = Invoke-Json POST "$cashierBase/orders/$($dashboardCashOrder.orderId)/checkout" $cashierSession @{
    discount = 0
    pointsUsed = 0
    paymentMethod = 'CASH'
    paymentAmount = ([decimal]$dashboardCashOrder.subtotal + 50000)
    idempotencyKey = [guid]::NewGuid().ToString('N')
}

$history = Invoke-Json GET "$cashierBase/history?take=30" $cashierSession
$cashHistoryBill = $history.bills | Where-Object { $_.billCode -eq $cashCheckout.billCode } | Select-Object -First 1

$checkoutStateAfterQrPreview = Invoke-Json GET "$billing/api/internal/checkout-state?orderId=$($dashboardOrderA.orderId)"

$appPage = Invoke-WebRequest -Uri "$base/app/cashier/Staff/Cashier/Index" -WebSession $cashierSession -TimeoutSec 60 -UseBasicParsing
$assetMatch = [regex]::Match($appPage.Content, '/app/cashier/assets/index-[^"]+\.js')
if (-not $assetMatch.Success) {
    throw 'Could not locate cashier runtime bundle asset.'
}

$bundleUrl = "$base$($assetMatch.Value)"
$bundle = Invoke-WebRequest -Uri $bundleUrl -WebSession $cashierSession -TimeoutSec 60 -UseBasicParsing

$summary = [ordered]@{
    success = $true
    branchId = $branchId
    dishId = $dishId
    qrOrder = [ordered]@{
        orderId = [int]$dashboardOrderA.orderId
        orderCode = [string]$dashboardOrderA.orderCode
        subtotal = [decimal]$dashboardOrderA.subtotal
        transferReference = $transferReferenceA
        qrUrl = $qrUrlA
        qrImageStatus = [int]$qrHead.StatusCode
        qrImageContentType = [string]$qrHead.Headers['Content-Type']
        checkoutStateBefore = $checkoutStateBefore
        checkoutStateAfterQrPreview = $checkoutStateAfterQrPreview
    }
    differentAmountCheck = [ordered]@{
        orderAAmount = [decimal]$dashboardOrderA.subtotal
        orderBAmount = [decimal]$dashboardOrderB.subtotal
        orderAReference = $transferReferenceA
        orderBReference = $transferReferenceB
        qrUrlA = $qrUrlA
        qrUrlB = $qrUrlB
        amountsDiffer = ([decimal]$dashboardOrderA.subtotal -ne [decimal]$dashboardOrderB.subtotal)
        qrUrlsDiffer = ($qrUrlA -ne $qrUrlB)
    }
    cashCheckout = [ordered]@{
        orderId = [int]$dashboardCashOrder.orderId
        orderCode = [string]$dashboardCashOrder.orderCode
        subtotal = [decimal]$dashboardCashOrder.subtotal
        billCode = [string]$cashCheckout.billCode
        totalAmount = [decimal]$cashCheckout.totalAmount
        changeAmount = [decimal]$cashCheckout.changeAmount
        historyContainsBill = ($null -ne $cashHistoryBill)
        historyPaymentMethod = if ($null -ne $cashHistoryBill) { [string]$cashHistoryBill.paymentMethod } else { $null }
    }
    runtimeBundleChecks = [ordered]@{
        bundleUrl = $bundleUrl
        hasQrIconMarker = $bundle.Content.Contains('bi-qr-code')
        hasVietQrEndpoint = $bundle.Content.Contains('img.vietqr.io/image/')
        hasBidvAccount = $bundle.Content.Contains('8830150124')
        hasCompactTemplate = $bundle.Content.Contains('compact2')
    }
    timestampUtc = [DateTime]::UtcNow.ToString('o')
}

$summary | ConvertTo-Json -Depth 10
