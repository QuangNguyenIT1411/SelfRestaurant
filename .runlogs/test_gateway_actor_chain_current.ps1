$ErrorActionPreference = 'Stop'

$base = 'http://localhost:5100'
$customerBase = "$base/api/gateway/customer"
$chefBase = "$base/api/gateway/staff"
$cashierBase = "$base/api/gateway/staff/cashier"
$adminBase = "$base/api/gateway/admin"
$summaryPath = 'C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main\.runlogs\gateway_actor_chain_current_summary.json'

$results = New-Object System.Collections.Generic.List[object]

function Get-NotificationId {
    param($Notification)

    if ($null -eq $Notification) {
        return $null
    }

    if ($Notification.PSObject.Properties.Name -contains 'notificationId') {
        return $Notification.notificationId
    }

    if ($Notification.PSObject.Properties.Name -contains 'readyDishNotificationId') {
        return $Notification.readyDishNotificationId
    }

    return $null
}

function Add-Result {
    param(
        [string]$Step,
        [bool]$Pass,
        [string]$Detail
    )

    $results.Add([pscustomobject]@{
        step = $Step
        pass = $Pass
        detail = $Detail
    }) | Out-Null

    $state = if ($Pass) { 'PASS' } else { 'FAIL' }
    Write-Host "[$state] $Step - $Detail"
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
        [Microsoft.PowerShell.Commands.WebRequestSession]$Session,
        $Body = $null
    )

    try {
        if ($null -eq $Body) {
            return Invoke-RestMethod -Method $Method -Uri $Uri -WebSession $Session -TimeoutSec 60
        }

        $json = $Body | ConvertTo-Json -Depth 20
        return Invoke-RestMethod -Method $Method -Uri $Uri -WebSession $Session -TimeoutSec 60 -ContentType 'application/json' -Body $json
    }
    catch {
        throw "$(Get-ErrorBody $_)"
    }
}

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Wait-For {
    param(
        [scriptblock]$Probe,
        [int]$TimeoutSeconds = 15,
        [int]$IntervalSeconds = 1
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        $value = & $Probe
        if ($null -ne $value) {
            return $value
        }

        Start-Sleep -Seconds $IntervalSeconds
    } while ((Get-Date) -lt $deadline)

    return $null
}

$customerSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$customerNoContextSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$chefSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$cashierSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$adminSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession

$stamp = Get-Date -Format 'yyyyMMddHHmmss'
$username = "chain_$stamp"
$password = 'Pass@123'
$phone = '09' + $stamp.Substring($stamp.Length - 8)
$email = "$username@example.com"
$branchId = $null
$tableId = $null
$dishId = $null
$orderId = $null
$billCode = $null

try {
    $health = Invoke-WebRequest "$base/healthz" -UseBasicParsing -TimeoutSec 20
    Assert-True ($health.StatusCode -eq 200) 'Gateway health check failed.'
    Add-Result 'Gateway Health' $true '200'

    $branches = Invoke-Json GET "$customerBase/branches" $customerSession
    Assert-True ($branches.Count -gt 0) 'Khong tai duoc danh sach chi nhanh.'
    $preferredBranch = $branches | Where-Object { [int]$_.branchId -eq 1 } | Select-Object -First 1
    if ($null -eq $preferredBranch) {
        $preferredBranch = $branches | Select-Object -First 1
    }
    $branchId = [int]$preferredBranch.branchId
    Add-Result 'Customer Branches' $true "branchId=$branchId"

    $tablesResponse = Invoke-Json GET "$customerBase/branches/$branchId/tables" $customerSession
    Assert-True ($tablesResponse.tables.Count -gt 0) "Khong co ban nao o chi nhanh $branchId."
    $table = $tablesResponse.tables | Where-Object { $_.statusCode -ne 'OCCUPIED' } | Select-Object -First 1
    if ($null -eq $table) {
        $table = $tablesResponse.tables | Select-Object -First 1
    }
    $tableId = [int]$table.tableId
    Add-Result 'Customer Tables' $true "tableId=$tableId"

    Invoke-Json POST "$customerBase/auth/register" $customerSession @{
        name = "Chain Test $stamp"
        username = $username
        password = $password
        phoneNumber = $phone
        email = $email
    } | Out-Null
    Add-Result 'Customer Register' $true $username

    $loginNoContext = Invoke-Json POST "$customerBase/auth/login" $customerNoContextSession @{
        username = $username
        password = $password
    }
    Assert-True ($loginNoContext.success) 'Dang nhap customer khong context that bai.'
    Assert-True ($loginNoContext.nextPath -eq '/Home/Index') "Customer login khong context redirect sai: $($loginNoContext.nextPath)"
    Add-Result 'Customer Login No Context' $true $loginNoContext.nextPath

    $logoutNoContext = Invoke-Json POST "$customerBase/auth/logout" $customerNoContextSession @{}
    Assert-True ($logoutNoContext.nextPath -eq '/Home/Index') "Customer logout redirect sai: $($logoutNoContext.nextPath)"
    Add-Result 'Customer Logout No Context' $true $logoutNoContext.nextPath

    Invoke-Json POST "$customerBase/context/table" $customerSession @{
        tableId = $tableId
        branchId = $branchId
    } | Out-Null
    Add-Result 'Customer Set Table Context' $true "branchId=$branchId tableId=$tableId"

    $loginCustomer = Invoke-Json POST "$customerBase/auth/login" $customerSession @{
        username = $username
        password = $password
    }
    Assert-True ($loginCustomer.success) 'Dang nhap customer co context that bai.'
    Assert-True ($loginCustomer.nextPath -eq '/Menu/Index') "Customer login co context redirect sai: $($loginCustomer.nextPath)"
    Add-Result 'Customer Login With Context' $true $loginCustomer.nextPath

    $customerSessionState = Invoke-Json GET "$customerBase/session" $customerSession
    Assert-True ($customerSessionState.authenticated) 'Session customer khong authenticated.'
    Assert-True ($null -ne $customerSessionState.tableContext) 'Session customer khong giu table context.'
    Add-Result 'Customer Session' $true "customerId=$($customerSessionState.customer.customerId)"

    $menu = Invoke-Json GET "$customerBase/menu" $customerSession
    foreach ($category in $menu.menu.categories) {
        $candidate = $category.dishes | Where-Object { $_.available } | Select-Object -First 1
        if ($null -ne $candidate) {
            $dishId = [int]$candidate.dishId
            break
        }
    }
    Assert-True ($null -ne $dishId) 'Khong tim thay mon dang ban de test.'
    Add-Result 'Customer Menu' $true "dishId=$dishId"

    $orderAfterAdd = Invoke-Json POST "$customerBase/order/items" $customerSession @{
        dishId = $dishId
        quantity = 1
        note = 'Chain test initial note'
    }
    $orderId = [int]$orderAfterAdd.orderId
    $itemId = [int]($orderAfterAdd.items | Select-Object -First 1).itemId
    Assert-True ($orderId -gt 0 -and $itemId -gt 0) 'Khong tao duoc order/item.'
    Add-Result 'Customer Add Item' $true "orderId=$orderId itemId=$itemId"

    Invoke-Json PATCH "$customerBase/order/items/$itemId/quantity" $customerSession @{ quantity = 2 } | Out-Null
    Invoke-Json PATCH "$customerBase/order/items/$itemId/note" $customerSession @{ note = 'Chain test updated note' } | Out-Null
    $activeOrder = Invoke-Json GET "$customerBase/order" $customerSession
    $activeItem = $activeOrder.items | Where-Object { [int]$_.itemId -eq $itemId } | Select-Object -First 1
    Assert-True ($null -ne $activeItem) 'Khong tim thay item sau khi update.'
    Assert-True ([int]$activeItem.quantity -eq 2) "So luong item khong dung: $($activeItem.quantity)"
    Assert-True ($activeItem.note -eq 'Chain test updated note') "Ghi chu item khong dung: $($activeItem.note)"
    Add-Result 'Customer Update Item' $true "quantity=$($activeItem.quantity)"

    $loyalty = Invoke-Json POST "$customerBase/order/scan-loyalty" $customerSession @{ phoneNumber = $phone }
    Assert-True ($loyalty.success) 'Scan loyalty that bai.'
    Add-Result 'Customer Scan Loyalty' $true $loyalty.message

    $submitOrder = Invoke-Json POST "$customerBase/order/submit" $customerSession @{}
    Assert-True ($submitOrder.success) 'Gui don xuong bep that bai.'
    Add-Result 'Customer Submit Order' $true $submitOrder.message

    $chefLogin = Invoke-Json POST "$chefBase/auth/login" $chefSession @{
        username = 'chef_hung'
        password = '123456'
    }
    Assert-True ($chefLogin.success) 'Chef login that bai.'
    Assert-True ($chefLogin.nextPath -eq '/Staff/Chef/Index') "Chef login redirect sai: $($chefLogin.nextPath)"
    Add-Result 'Chef Login' $true $chefLogin.nextPath

    $chefDashboardPending = Invoke-Json GET "$chefBase/chef/dashboard" $chefSession
    $pendingOrder = $chefDashboardPending.pendingOrders | Where-Object { [int]$_.orderId -eq $orderId } | Select-Object -First 1
    Assert-True ($null -ne $pendingOrder) "Chef khong thay order $orderId trong pending."
    Add-Result 'Chef Pending Order Visible' $true "orderId=$orderId"

    Invoke-Json PATCH "$chefBase/chef/orders/$orderId/items/$itemId/note" $chefSession @{
        note = 'Chef chain note'
        append = $false
    } | Out-Null
    $chefStart = Invoke-Json POST "$chefBase/chef/orders/$orderId/start" $chefSession @{}
    Assert-True ($chefStart.success) 'Chef start order that bai.'
    Add-Result 'Chef Start Order' $true $chefStart.message

    $chefReady = Invoke-Json POST "$chefBase/chef/orders/$orderId/ready" $chefSession @{}
    Assert-True ($chefReady.success) 'Chef ready order that bai.'
    Add-Result 'Chef Ready Order' $true $chefReady.message

    $readyNotification = Wait-For -TimeoutSeconds 15 -IntervalSeconds 1 -Probe {
        $readyNotifications = Invoke-Json GET "$customerBase/ready-notifications" $customerSession
        $readyNotifications.items | Where-Object { [int]$_.orderId -eq $orderId } | Select-Object -First 1
    }
    Assert-True ($null -ne $readyNotification) "Customer khong nhan duoc ready notification cho order $orderId."
    $notificationId = Get-NotificationId $readyNotification
    Assert-True ($notificationId -gt 0) "Customer ready notification khong co id hop le cho order $orderId."
    Add-Result 'Customer Ready Notification' $true "notificationId=$notificationId"

    Invoke-Json POST "$customerBase/ready-notifications/$notificationId/resolve" $customerSession @{} | Out-Null
    Add-Result 'Customer Resolve Notification' $true "notificationId=$notificationId"

    $chefServe = Invoke-Json POST "$chefBase/chef/orders/$orderId/serve" $chefSession @{}
    Assert-True ($chefServe.success) 'Chef serve order that bai.'
    Add-Result 'Chef Serve Order' $true $chefServe.message

    $customerConfirm = Invoke-Json POST "$customerBase/order/confirm-received?orderId=$orderId" $customerSession @{}
    Assert-True ($customerConfirm.success) 'Customer confirm received that bai.'
    Add-Result 'Customer Confirm Received' $true $customerConfirm.message

    $cashierLogin = Invoke-Json POST "$cashierBase/auth/login" $cashierSession @{
        username = 'cashier_lan'
        password = '123456'
    }
    Assert-True ($cashierLogin.success) 'Cashier login that bai.'
    Assert-True ($cashierLogin.nextPath -eq '/Staff/Cashier/Index') "Cashier login redirect sai: $($cashierLogin.nextPath)"
    Add-Result 'Cashier Login' $true $cashierLogin.nextPath

    $cashierDashboard = Invoke-Json GET "$cashierBase/dashboard" $cashierSession
    $cashierOrder = $cashierDashboard.orders | Where-Object { [int]$_.orderId -eq $orderId } | Select-Object -First 1
    Assert-True ($null -ne $cashierOrder) "Cashier khong thay order $orderId trong dashboard."
    Add-Result 'Cashier Order Visible' $true "orderId=$orderId"

    $checkout = Invoke-Json POST "$cashierBase/orders/$orderId/checkout" $cashierSession @{
        discount = 0
        pointsUsed = 0
        paymentMethod = 'CASH'
        paymentAmount = ([decimal]$cashierOrder.subtotal + 50000)
    }
    $billCode = [string]$checkout.billCode
    Assert-True (-not [string]::IsNullOrWhiteSpace($billCode)) 'Cashier checkout khong tra billCode.'
    Add-Result 'Cashier Checkout' $true $billCode

    $history = Invoke-Json GET "$cashierBase/history?take=30" $cashierSession
    $historyBill = $history.bills | Where-Object { $_.billCode -eq $billCode } | Select-Object -First 1
    Assert-True ($null -ne $historyBill) "Cashier history khong co bill $billCode."
    Add-Result 'Cashier History Contains Bill' $true $billCode

    $reportDate = (Get-Date).ToString('yyyy-MM-dd')
    $report = Invoke-Json GET "$cashierBase/report?date=$reportDate" $cashierSession
    $reportBill = $report.bills | Where-Object { $_.billCode -eq $billCode } | Select-Object -First 1
    Assert-True ($null -ne $reportBill) "Cashier report khong co bill $billCode."
    Add-Result 'Cashier Report Contains Bill' $true $billCode

    $adminLogin = Invoke-Json POST "$adminBase/auth/login" $adminSession @{
        username = 'admin'
        password = '123456'
    }
    Assert-True ($adminLogin.success) 'Admin login that bai.'
    Assert-True ($adminLogin.nextPath -eq '/Admin/Dashboard/Index') "Admin login redirect sai: $($adminLogin.nextPath)"
    Add-Result 'Admin Login' $true $adminLogin.nextPath

    $adminDashboard = Invoke-Json GET "$adminBase/dashboard" $adminSession
    Assert-True ($null -ne $adminDashboard.stats) 'Admin dashboard khong co stats.'
    Add-Result 'Admin Dashboard' $true "todayRevenue=$($adminDashboard.stats.todayRevenue)"

    $adminCustomers = Invoke-Json GET "$adminBase/customers?search=$([uri]::EscapeDataString($username))" $adminSession
    $adminCustomer = $adminCustomers.customers.items | Where-Object { $_.username -eq $username } | Select-Object -First 1
    Assert-True ($null -ne $adminCustomer) "Admin khong tim thay customer $username."
    Add-Result 'Admin Customers Search' $true "customerId=$($adminCustomer.customerId)"

    $adminReports = Invoke-Json GET "$adminBase/reports" $adminSession
    Assert-True ($adminReports.revenue.totalRevenue -ge 0) 'Admin reports tra ve du lieu khong hop le.'
    Add-Result 'Admin Reports' $true "revenueRows=$(@($adminReports.revenue.revenueByBranchDate).Count)"

    $customerHistory = Invoke-Json GET "$customerBase/orders/history?take=20" $customerSession
    $historyOrder = $customerHistory | Where-Object { [int]$_.orderId -eq $orderId } | Select-Object -First 1
    Assert-True ($null -ne $historyOrder) "Customer history khong co order $orderId."
    Add-Result 'Customer Order History' $true "orderId=$orderId"

    $customerDashboard = Invoke-Json GET "$customerBase/dashboard" $customerSession
    $recentOrder = $customerDashboard.recentOrders | Where-Object { [int]$_.orderId -eq $orderId } | Select-Object -First 1
    Assert-True ($null -ne $recentOrder) "Customer dashboard khong co recent order $orderId."
    Add-Result 'Customer Dashboard Recent Orders' $true "orderId=$orderId"

    $logoutCustomer = Invoke-Json POST "$customerBase/auth/logout" $customerSession @{}
    Assert-True ($logoutCustomer.nextPath -eq '/Home/Index') "Customer logout redirect sai: $($logoutCustomer.nextPath)"
    Add-Result 'Customer Logout Preserves Context' $true $logoutCustomer.nextPath

    $reloginCustomer = Invoke-Json POST "$customerBase/auth/login" $customerSession @{
        username = $username
        password = $password
    }
    Assert-True ($reloginCustomer.success) 'Customer relogin sau logout that bai.'
    Assert-True ($reloginCustomer.nextPath -eq '/Menu/Index') "Customer relogin sau logout redirect sai: $($reloginCustomer.nextPath)"
    Add-Result 'Customer Relogin With Preserved Context' $true $reloginCustomer.nextPath
}
catch {
    Add-Result 'Actor Chain Current' $false $_.Exception.Message
}
finally {
    try { Invoke-Json POST "$customerBase/auth/logout" $customerSession @{} | Out-Null } catch {}
    try { Invoke-Json POST "$chefBase/auth/logout" $chefSession @{} | Out-Null } catch {}
    try { Invoke-Json POST "$cashierBase/auth/logout" $cashierSession @{} | Out-Null } catch {}
    try { Invoke-Json POST "$adminBase/auth/logout" $adminSession @{} | Out-Null } catch {}
}

$resultItems = @($results.ToArray())
$summary = [pscustomobject]@{
    total = $resultItems.Count
    passed = @($resultItems | Where-Object { $_.pass -eq $true }).Count
    failed = @($resultItems | Where-Object { $_.pass -ne $true }).Count
    username = $username
    phone = $phone
    branchId = $branchId
    tableId = $tableId
    dishId = $dishId
    orderId = $orderId
    billCode = $billCode
    results = $resultItems
}
$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding UTF8

if ($summary.failed -gt 0) {
    exit 1
}

Write-Host "PASS actor-chain order=$orderId bill=$billCode branch=$branchId table=$tableId"
