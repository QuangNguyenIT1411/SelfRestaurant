$ErrorActionPreference = 'Stop'

$base = 'http://localhost:5100'
$customerBase = "$base/api/gateway/customer"
$cashierBase = "$base/api/gateway/staff/cashier"
$summaryPath = 'C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main\.runlogs\gateway_api_cashier_smoke_summary.json'

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
$cashierSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession

$cashierLogin = Invoke-JsonSend Post "$cashierBase/auth/login" @{ username = 'cashier_lan'; password = '123456' } $cashierSession
$branchId = [int]$cashierLogin.session.staff.branchId

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
$username = "cash_api_$stamp"
$password = '123456'
$phone = '09' + $stamp.Substring($stamp.Length - 8)
[void](Invoke-JsonSend Post "$customerBase/auth/register" @{
    name = "Cash Api $stamp"
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

[void](Invoke-JsonSend Post "$customerBase/order/items" @{ dishId = [int]$dish.dishId; quantity = 2; note = 'cashier api smoke' } $customerSession)
$orderBeforeSubmit = Invoke-JsonGet "$customerBase/order" $customerSession
$orderId = [int]$orderBeforeSubmit.orderId
[void](Invoke-JsonSend Post "$customerBase/order/submit" $null $customerSession)

$dashboard = Invoke-JsonGet "$cashierBase/dashboard" $cashierSession
$dashboardOrder = $dashboard.orders | Where-Object { [int]$_.orderId -eq $orderId } | Select-Object -First 1
if ($null -eq $dashboardOrder) {
    $dashboardIds = @($dashboard.orders | ForEach-Object { [int]$_.orderId })
    throw "Submitted order $orderId not visible in cashier dashboard: $($dashboardIds -join ',')"
}

$paymentAmount = [decimal]$dashboardOrder.subtotal + 50000
$checkout = Invoke-JsonSend Post "$cashierBase/orders/$orderId/checkout" @{
    discount = 0
    pointsUsed = 0
    paymentMethod = 'CASH'
    paymentAmount = $paymentAmount
} $cashierSession

$history = Invoke-JsonGet "$cashierBase/history?take=20" $cashierSession
$historyBill = $history.bills | Where-Object { $_.billCode -eq $checkout.billCode } | Select-Object -First 1
if ($null -eq $historyBill) {
    throw "Bill $($checkout.billCode) not found in cashier history"
}

$reportDate = (Get-Date).ToString('yyyy-MM-dd')
$report = Invoke-JsonGet "$cashierBase/report?date=$reportDate" $cashierSession
$reportBill = $report.bills | Where-Object { $_.billCode -eq $checkout.billCode } | Select-Object -First 1
if ($null -eq $reportBill) {
    throw "Bill $($checkout.billCode) not found in cashier report for $reportDate"
}

$summary = [ordered]@{
    success = $true
    branchId = $branchId
    tableId = [int]$table.tableId
    orderId = $orderId
    billCode = $checkout.billCode
    totalAmount = [decimal]$checkout.totalAmount
    changeAmount = [decimal]$checkout.changeAmount
    historyContainsBill = $true
    reportContainsBill = $true
    timestampUtc = [DateTime]::UtcNow.ToString('o')
}
$summary | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
Write-Host "PASS order=$orderId bill=$($checkout.billCode) branch=$branchId"
