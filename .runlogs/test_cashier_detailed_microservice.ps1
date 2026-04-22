$ErrorActionPreference = 'Stop'

$base = 'http://localhost:5100'
$catalog = 'http://localhost:5101'
$orders = 'http://localhost:5102'
$cashierBase = "$base/api/gateway/staff/cashier"
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$results = New-Object System.Collections.Generic.List[object]
$cashierUser = 'cashier_lan'
$cashierPasswordCurrent = '123456'
$cashierPasswordTemp = 'Temp@Cash123'
$originalProfile = $null

function Add-Result([string]$Feature, [bool]$Pass, [string]$Detail) {
    $results.Add([pscustomobject]@{
        ChucNang = $Feature
        Pass = $Pass
        ChiTiet = $Detail
    }) | Out-Null
    $state = if ($Pass) { 'PASS' } else { 'FAIL' }
    Write-Output "[$state] $Feature - $Detail"
}

function Get-ErrorBody {
    param($ErrorRecord)
    $response = $ErrorRecord.Exception.Response
    if ($response -and $response.GetResponseStream()) {
        $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
        return $reader.ReadToEnd()
    }
    return $ErrorRecord.Exception.Message
}

function Invoke-Json {
    param(
        [ValidateSet('GET', 'POST', 'PUT', 'PATCH', 'DELETE')][string]$Method,
        [string]$Uri,
        [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession,
        $Body = $null
    )

    try {
        if ($null -eq $Body) {
            return Invoke-RestMethod -Method $Method -Uri $Uri -WebSession $WebSession -TimeoutSec 60
        }

        $json = $Body | ConvertTo-Json -Depth 20
        $payload = [System.Text.Encoding]::UTF8.GetBytes($json)
        return Invoke-RestMethod -Method $Method -Uri $Uri -WebSession $WebSession -TimeoutSec 60 -ContentType 'application/json; charset=utf-8' -Body $payload
    }
    catch {
        throw (Get-ErrorBody $_)
    }
}

function Invoke-JsonNoSession {
    param(
        [ValidateSet('GET', 'POST', 'PUT', 'PATCH', 'DELETE')][string]$Method,
        [string]$Uri,
        $Body = $null
    )

    try {
        if ($null -eq $Body) {
            return Invoke-RestMethod -Method $Method -Uri $Uri -TimeoutSec 60
        }

        $json = $Body | ConvertTo-Json -Depth 20
        $payload = [System.Text.Encoding]::UTF8.GetBytes($json)
        return Invoke-RestMethod -Method $Method -Uri $Uri -TimeoutSec 60 -ContentType 'application/json; charset=utf-8' -Body $payload
    }
    catch {
        throw (Get-ErrorBody $_)
    }
}

function Expect-ApiError {
    param(
        [ValidateSet('GET', 'POST', 'PUT', 'PATCH', 'DELETE')][string]$Method,
        [string]$Uri,
        [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession,
        $Body = $null
    )

    try {
        $null = Invoke-Json $Method $Uri $WebSession $Body
        throw "Expected API error at $Uri but request succeeded."
    }
    catch {
        $raw = $_.Exception.Message
        try { return $raw | ConvertFrom-Json } catch { throw $raw }
    }
}

function Find-AvailableTable([int]$BranchId, [int[]]$ExcludeTableIds) {
    $tables = Invoke-RestMethod -Method GET -Uri "$catalog/api/branches/$BranchId/tables" -TimeoutSec 60
    $table = $tables.tables | Where-Object { $_.isAvailable -and $ExcludeTableIds -notcontains [int]$_.tableId } | Select-Object -First 1
    if ($null -eq $table) {
        $table = $tables.tables | Where-Object { $ExcludeTableIds -notcontains [int]$_.tableId } | Select-Object -First 1
    }
    return $table
}

function New-TestOrder([int]$BranchId, [int]$DishId, [string]$Note, [int[]]$ExcludeTableIds) {
    $table = Find-AvailableTable $BranchId $ExcludeTableIds
    $tableId = [int]$table.tableId
    Invoke-JsonNoSession POST "$orders/api/tables/$tableId/reset" @{} | Out-Null
    Invoke-JsonNoSession POST "$orders/api/tables/$tableId/order/items" @{
        dishId = $DishId
        quantity = 1
        note = $Note
    } | Out-Null
    Invoke-JsonNoSession POST "$orders/api/tables/$tableId/order/submit" @{
        idempotencyKey = [guid]::NewGuid().ToString('N')
        expectedDiningSessionCode = $null
    } | Out-Null
    $active = Invoke-JsonNoSession GET "$orders/api/tables/$tableId/order"
    return [pscustomobject]@{
        TableId = $tableId
        OrderId = [int]$active.orderId
    }
}

try {
    Invoke-JsonNoSession POST "$base/api/gateway/customer/dev/reset-test-state" @{} | Out-Null
    Add-Result 'Reset test state' $true 'ok'

    $login = Invoke-Json POST "$cashierBase/auth/login" $session @{
        username = $cashierUser
        password = $cashierPasswordCurrent
    }
    Add-Result 'Dang nhap Cashier' ([bool]$login.success -and $login.nextPath -eq '/Staff/Cashier/Index') $login.nextPath

    foreach ($route in @('/app/cashier/Staff/Account/Login', '/app/cashier/Staff/Cashier/Index', '/app/cashier/Staff/Cashier/History', '/app/cashier/Staff/Cashier/Report')) {
        $page = Invoke-WebRequest "$base$route" -WebSession $session -UseBasicParsing -TimeoutSec 30
        Add-Result "Route $route" ($page.StatusCode -eq 200) '200'
    }

    $dashboard = Invoke-Json GET "$cashierBase/dashboard" $session
    $history = Invoke-Json GET "$cashierBase/history?take=20" $session
    $reportDate = (Get-Date).ToString('yyyy-MM-dd')
    $report = Invoke-Json GET "$cashierBase/report?date=$reportDate" $session
    Add-Result 'Dashboard Cashier' ($null -ne $dashboard.account) "tables=$(@($dashboard.tables).Count)"
    Add-Result 'History Cashier' ($null -ne $history.account) "bills=$(@($history.bills).Count)"
    Add-Result 'Report Cashier' ($null -ne $report.staff) "billCount=$($report.billCount)"

    $originalProfile = [pscustomobject]@{
        Name = [string]$history.account.name
        Phone = [string]$history.account.phone
        Email = [string]$history.account.email
    }

    $branchId = [int]$dashboard.staff.branchId
    $menu = Invoke-RestMethod -Method GET -Uri "$catalog/api/branches/$branchId/menu" -TimeoutSec 60
    $dish = $null
    foreach ($category in @($menu.categories)) {
        $dish = @($category.dishes | Where-Object { $_.available }) | Select-Object -First 1
        if ($dish) { break }
    }
    if ($null -eq $dish) { throw 'Khong tim thay mon dang ban de test cashier.' }
    $dishId = [int]$dish.dishId
    Add-Result 'Lay mon de test thanh toan' ($dishId -gt 0) "dishId=$dishId"

    $usedTables = @()
    $order1 = New-TestOrder -BranchId $branchId -DishId $dishId -Note 'cashier-insufficient' -ExcludeTableIds $usedTables
    $usedTables += $order1.TableId
    $insufficient = Expect-ApiError POST "$cashierBase/orders/$($order1.OrderId)/checkout" $session @{
        discount = 0
        pointsUsed = 0
        paymentMethod = 'CASH'
        paymentAmount = 1
    }
    $insufficientCode = if ($null -ne $insufficient -and -not [string]::IsNullOrWhiteSpace([string]$insufficient.code)) { [string]$insufficient.code } else { 'unknown' }
    Add-Result 'Chan tien mat khong du' ($insufficientCode -eq 'checkout_failed') $insufficientCode

    $invalidMethod = Expect-ApiError POST "$cashierBase/orders/$($order1.OrderId)/checkout" $session @{
        discount = 0
        pointsUsed = 0
        paymentMethod = 'BADMETHOD'
        paymentAmount = 999999
    }
    $invalidMethodCode = if ($null -ne $invalidMethod -and -not [string]::IsNullOrWhiteSpace([string]$invalidMethod.code)) { [string]$invalidMethod.code } else { 'unknown' }
    Add-Result 'Chan payment method sai' ($invalidMethodCode -eq 'checkout_failed') $invalidMethodCode

    $checkout1 = Invoke-Json POST "$cashierBase/orders/$($order1.OrderId)/checkout" $session @{
        discount = 0
        pointsUsed = 0
        paymentMethod = 'CASH'
        paymentAmount = 999999
        idempotencyKey = [guid]::NewGuid().ToString('N')
    }
    Add-Result 'Thanh toan CASH' (-not [string]::IsNullOrWhiteSpace($checkout1.billCode)) $checkout1.billCode

    $order2 = New-TestOrder -BranchId $branchId -DishId $dishId -Note 'cashier-card' -ExcludeTableIds $usedTables
    $usedTables += $order2.TableId
    $checkout2 = Invoke-Json POST "$cashierBase/orders/$($order2.OrderId)/checkout" $session @{
        discount = 0
        pointsUsed = 0
        paymentMethod = 'CARD'
        paymentAmount = 0
        idempotencyKey = [guid]::NewGuid().ToString('N')
    }
    Add-Result 'Thanh toan CARD' (-not [string]::IsNullOrWhiteSpace($checkout2.billCode)) $checkout2.billCode

    $order3 = New-TestOrder -BranchId $branchId -DishId $dishId -Note 'cashier-transfer' -ExcludeTableIds $usedTables
    $checkout3 = Invoke-Json POST "$cashierBase/orders/$($order3.OrderId)/checkout" $session @{
        discount = 0
        pointsUsed = 0
        paymentMethod = 'TRANSFER'
        paymentAmount = 0
        idempotencyKey = [guid]::NewGuid().ToString('N')
    }
    Add-Result 'Thanh toan TRANSFER' (-not [string]::IsNullOrWhiteSpace($checkout3.billCode)) $checkout3.billCode

    $historyAfter = Invoke-Json GET "$cashierBase/history?take=50" $session
    $billSeen = @($historyAfter.bills | Where-Object { $_.billCode -eq $checkout1.billCode -or $_.billCode -eq $checkout2.billCode -or $_.billCode -eq $checkout3.billCode }).Count
    Add-Result 'Lich su co bill moi' ($billSeen -ge 3) "matched=$billSeen"

    $reportAfter = Invoke-Json GET "$cashierBase/report?date=$reportDate" $session
    $reportSeen = @($reportAfter.bills | Where-Object { $_.billCode -eq $checkout1.billCode -or $_.billCode -eq $checkout2.billCode -or $_.billCode -eq $checkout3.billCode }).Count
    Add-Result 'Bao cao co bill moi' ($reportSeen -ge 3) "matched=$reportSeen"

    $updateProfileResp = Invoke-Json PUT "$cashierBase/account" $session @{
        name = 'Thu ngan Lan QA'
        phone = '0905222333'
        email = 'lan.cashier+qa@selfrestaurant.com'
    }
    Add-Result 'Cap nhat tai khoan Cashier' ($updateProfileResp.phone -eq '0905222333') $updateProfileResp.phone

    $mismatch = Expect-ApiError POST "$cashierBase/change-password" $session @{
        currentPassword = $cashierPasswordCurrent
        newPassword = $cashierPasswordTemp
        confirmPassword = 'sai'
    }
    Add-Result 'Chan sai xac nhan mat khau' ($mismatch.code -eq 'password_mismatch') $mismatch.code

    $changeResp = Invoke-Json POST "$cashierBase/change-password" $session @{
        currentPassword = $cashierPasswordCurrent
        newPassword = $cashierPasswordTemp
        confirmPassword = $cashierPasswordTemp
    }
    $cashierPasswordCurrent = $cashierPasswordTemp
    Add-Result 'Doi mat khau Cashier' ([bool]$changeResp.success) $changeResp.message

    Invoke-Json POST "$cashierBase/auth/logout" $session @{} | Out-Null
    $relogin = Invoke-Json POST "$cashierBase/auth/login" $session @{
        username = $cashierUser
        password = $cashierPasswordCurrent
    }
    Add-Result 'Dang nhap bang mat khau moi' ([bool]$relogin.success) $relogin.nextPath
}
catch {
    Add-Result 'ERROR' $false $_.Exception.Message
}
finally {
    try {
        if ($null -ne $originalProfile) {
            Invoke-Json PUT "$cashierBase/account" $session @{
                name = $originalProfile.Name
                phone = $originalProfile.Phone
                email = $originalProfile.Email
            } | Out-Null
        }
    } catch {}

    try {
        if ($cashierPasswordCurrent -ne '123456') {
            Invoke-Json POST "$cashierBase/change-password" $session @{
                currentPassword = $cashierPasswordCurrent
                newPassword = '123456'
                confirmPassword = '123456'
            } | Out-Null
            $cashierPasswordCurrent = '123456'
        }
    } catch {}

    try { Invoke-Json POST "$cashierBase/auth/logout" $session @{} | Out-Null } catch {}
}

$results | Format-Table -AutoSize | Out-String | Write-Output
$pass = ($results | Where-Object { $_.Pass -eq $true }).Count
$total = $results.Count
Write-Output "SUMMARY: $pass/$total PASS"
if ($pass -ne $total) { exit 1 }
