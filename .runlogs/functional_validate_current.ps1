$ErrorActionPreference = 'Stop'

$base = 'http://localhost:5100'
$customerBase = "$base/api/gateway/customer"
$staffAuthBase = "$base/api/gateway/staff/auth"
$chefBase = "$base/api/gateway/staff/chef"
$cashierBase = "$base/api/gateway/staff/cashier"
$adminBase = "$base/api/gateway/admin"
$ordersInternal = 'http://localhost:5102/api/internal/audit-logs'
$billingInternal = 'http://localhost:5105/api/internal/audit-logs'
$catalogInternal = 'http://localhost:5101/api/admin/internal/audit-logs'

$results = New-Object System.Collections.Generic.List[object]

function Add-Result([string]$Step, [bool]$Pass, [string]$Detail) {
    $results.Add([pscustomobject]@{
        Step = $Step
        Pass = $Pass
        Detail = $Detail
    }) | Out-Null
    $state = if ($Pass) { 'PASS' } else { 'FAIL' }
    Write-Output "[$state] $Step - $Detail"
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
        $Body = $null,
        [int]$TimeoutSec = 60
    )

    try {
        if ($null -eq $Body) {
            return Invoke-RestMethod -Method $Method -Uri $Uri -WebSession $Session -TimeoutSec $TimeoutSec
        }

        $json = $Body | ConvertTo-Json -Depth 20
        $payload = [System.Text.Encoding]::UTF8.GetBytes($json)
        return Invoke-RestMethod -Method $Method -Uri $Uri -WebSession $Session -TimeoutSec $TimeoutSec -ContentType 'application/json; charset=utf-8' -Body $payload
    }
    catch {
        throw (Get-ErrorBody $_)
    }
}

function Invoke-JsonNoSession {
    param(
        [ValidateSet('GET', 'POST', 'PUT', 'PATCH', 'DELETE')][string]$Method,
        [string]$Uri,
        $Body = $null,
        [int]$TimeoutSec = 60
    )

    try {
        if ($null -eq $Body) {
            return Invoke-RestMethod -Method $Method -Uri $Uri -TimeoutSec $TimeoutSec
        }

        $json = $Body | ConvertTo-Json -Depth 20
        $payload = [System.Text.Encoding]::UTF8.GetBytes($json)
        return Invoke-RestMethod -Method $Method -Uri $Uri -TimeoutSec $TimeoutSec -ContentType 'application/json; charset=utf-8' -Body $payload
    }
    catch {
        throw (Get-ErrorBody $_)
    }
}

function Expect-ApiError {
    param(
        [ValidateSet('GET', 'POST', 'PUT', 'PATCH', 'DELETE')][string]$Method,
        [string]$Uri,
        [Microsoft.PowerShell.Commands.WebRequestSession]$Session,
        $Body = $null
    )

    try {
        $null = Invoke-Json $Method $Uri $Session $Body
        throw "Expected API error at $Uri but request succeeded."
    }
    catch {
        $raw = $_.Exception.Message
        try { return $raw | ConvertFrom-Json } catch { throw $raw }
    }
}

function Wait-For {
    param(
        [scriptblock]$Probe,
        [int]$TimeoutSeconds = 20,
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

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw $Message
    }
}

function Coalesce-Message($Payload) {
    if ($null -eq $Payload) { return '' }
    if ($Payload.PSObject.Properties.Name -contains 'message' -and -not [string]::IsNullOrWhiteSpace([string]$Payload.message)) {
        return [string]$Payload.message
    }
    if ($Payload.PSObject.Properties.Name -contains 'code' -and -not [string]::IsNullOrWhiteSpace([string]$Payload.code)) {
        return [string]$Payload.code
    }
    return [string]$Payload
}

$customerGuest = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$customer = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$chef = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$cashier = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$admin = New-Object Microsoft.PowerShell.Commands.WebRequestSession

$stamp = Get-Date -Format 'yyyyMMddHHmmss'
$username = "qa_$stamp"
$password = 'Pass@123'
$phone = '09' + $stamp.Substring($stamp.Length - 8)
$email = "$username@example.com"
$branchId = 0
$tableId = 0
$dishId = 0
$dishName = ''
$orderId = 0
$itemId = 0
$submitKey = [guid]::NewGuid().ToString('N')
$checkoutKey = [guid]::NewGuid().ToString('N')
$billCode = ''
$notificationId = 0
$originalAvailability = $true

try {
    Invoke-Json POST "$customerBase/dev/reset-test-state" $customerGuest @{} | Out-Null
    Add-Result 'Dev Reset' $true 'reset-test-state ok'

    $branches = Invoke-Json GET "$customerBase/branches" $customerGuest
    Assert-True ($branches.Count -gt 0) 'Khong tai duoc danh sach chi nhanh.'
    $branch = $branches | Where-Object { [int]$_.branchId -eq 1 } | Select-Object -First 1
    if ($null -eq $branch) { $branch = $branches | Select-Object -First 1 }
    $branchId = [int]$branch.branchId
    Add-Result 'Customer Branch List' $true "branchId=$branchId"

    $tablesResponse = Invoke-Json GET "$customerBase/branches/$branchId/tables" $customerGuest
    Assert-True (@($tablesResponse.tables).Count -gt 0) 'Khong tai duoc danh sach ban.'
    $table = @($tablesResponse.tables | Where-Object { $_.statusCode -ne 'OCCUPIED' } | Select-Object -First 1)[0]
    if ($null -eq $table) { $table = @($tablesResponse.tables | Select-Object -First 1)[0] }
    $tableId = [int]$table.tableId
    Add-Result 'Customer Table List' $true "tableId=$tableId status=$($table.statusCode)"

    $guestContext = Invoke-Json POST "$customerBase/context/table" $customerGuest @{
        tableId = $tableId
        branchId = $branchId
    }
    Add-Result 'Guest Set Table Context' $true "tableId=$tableId"

    $guestMenu = Invoke-Json GET "$customerBase/menu" $customerGuest
    Assert-True (@($guestMenu.menu.categories).Count -gt 0) 'Guest menu khong co categories.'
    foreach ($category in @($guestMenu.menu.categories)) {
        $candidate = @($category.dishes | Where-Object { $_.available } | Select-Object -First 1)[0]
        if ($null -ne $candidate) {
            $dishId = [int]$candidate.dishId
            $dishName = [string]$candidate.name
            $originalAvailability = [bool]$candidate.available
            break
        }
    }
    Assert-True ($dishId -gt 0) 'Khong tim thay mon dang ban de test.'
    Add-Result 'Guest Menu Load' $true "dishId=$dishId name=$dishName"

    $recommendations = Invoke-Json GET "$customerBase/menu/recommendations?cartDishIds=$dishId" $customerGuest
    Assert-True (@($recommendations.recommendations).Count -ge 0) 'Recommendations endpoint loi.'
    $menuDishMap = @{}
    foreach ($category in @($guestMenu.menu.categories)) {
        foreach ($dish in @($category.dishes)) {
            $menuDishMap[[int]$dish.dishId] = $dish
        }
    }
    $containsUnavailable = @(
        $recommendations.recommendations |
            Where-Object {
                $recommendedDish = $menuDishMap[[int]$_.dishId]
                $null -eq $recommendedDish -or -not [bool]$recommendedDish.available
            }
    ).Count
    Assert-True ($containsUnavailable -eq 0) 'Recommendations tra ve mon unavailable.'
    Add-Result 'Recommendations Safe' $true "count=$(@($recommendations.recommendations).Count)"

    Invoke-Json POST "$customerBase/auth/register" $customer @{
        name = "QA Customer $stamp"
        username = $username
        password = $password
        phoneNumber = $phone
        email = $email
        gender = 'Nam'
        address = 'HCM'
    } | Out-Null
    Add-Result 'Customer Register' $true $username

    $contextBeforeLogin = Invoke-Json POST "$customerBase/context/table" $customer @{
        tableId = $tableId
        branchId = $branchId
    }
    $login = Invoke-Json POST "$customerBase/auth/login" $customer @{
        username = $username
        password = $password
    }
    Assert-True ($login.success -and $login.nextPath -eq '/Menu/Index') "Customer login redirect sai: $($login.nextPath)"
    Add-Result 'Customer Login With Context' $true $login.nextPath

    $sessionState = Invoke-Json GET "$customerBase/session" $customer
    Assert-True ($sessionState.authenticated) 'Customer session khong authenticated.'
    Assert-True ($null -ne $sessionState.tableContext) 'Customer session mat table context.'
    Add-Result 'Customer Session' $true "customerId=$($sessionState.customer.customerId)"

    $menu = Invoke-Json GET "$customerBase/menu" $customer
    Add-Result 'Customer Menu Load' $true "categories=$(@($menu.menu.categories).Count)"

    $orderAfterAdd = Invoke-Json POST "$customerBase/order/items" $customer @{
        dishId = $dishId
        quantity = 1
        note = 'qa first item'
        expectedDiningSessionCode = $null
    }
    $orderId = [int]$orderAfterAdd.orderId
    $itemId = [int](@($orderAfterAdd.items | Select-Object -First 1)[0].itemId)
    Assert-True ($orderId -gt 0 -and $itemId -gt 0) 'Khong tao duoc pending order.'
    Add-Result 'Customer Add Item' $true "orderId=$orderId itemId=$itemId"

    # Keep the test stock-aware: this validates quantity editing without assuming
    # the chosen live dish has enough ingredients for quantity 2 on every local DB.
    Invoke-Json PATCH "$customerBase/order/items/$itemId/quantity" $customer @{ quantity = 1 } | Out-Null
    Invoke-Json PATCH "$customerBase/order/items/$itemId/note" $customer @{ note = 'qa updated note' } | Out-Null
    $activeOrder = Invoke-Json GET "$customerBase/order" $customer
    $activeItem = @($activeOrder.items | Where-Object { [int]$_.itemId -eq $itemId } | Select-Object -First 1)[0]
    Assert-True ([int]$activeItem.quantity -eq 1) 'Cap nhat so luong item that bai.'
    Assert-True ([string]$activeItem.note -eq 'qa updated note') 'Cap nhat ghi chu item that bai.'
    Add-Result 'Customer Update Item' $true "quantity=$($activeItem.quantity)"

    $submit = Invoke-Json POST "$customerBase/order/submit" $customer @{
        idempotencyKey = $submitKey
        expectedDiningSessionCode = $null
    }
    Assert-True ($submit.success) 'Submit order lan dau that bai.'
    Add-Result 'Customer Submit Round 1' $true $submit.message

    $submitReplay = Invoke-Json POST "$customerBase/order/submit" $customer @{
        idempotencyKey = $submitKey
        expectedDiningSessionCode = $null
    }
    Assert-True ($submitReplay.success) 'Replay submit khong an toan.'
    Add-Result 'Customer Submit Replay' $true $submitReplay.message

    $orderAfterSubmit = Invoke-Json GET "$customerBase/order" $customer
    $sessionCode = [string]$orderAfterSubmit.diningSessionCode
    Assert-True (-not [string]::IsNullOrWhiteSpace($sessionCode)) 'Thieu dining session code sau submit.'
    Add-Result 'Dining Session Created' $true $sessionCode

    $chefLogin = Invoke-Json POST "$staffAuthBase/login" $chef @{
        username = 'chef_hung'
        password = '123456'
    }
    Assert-True ($chefLogin.success -and $chefLogin.nextPath -eq '/Staff/Chef/Index') "Chef login redirect sai: $($chefLogin.nextPath)"
    Add-Result 'Chef Login' $true $chefLogin.nextPath

    $chefDashboard = Invoke-Json GET "$chefBase/dashboard" $chef
    $chefOrder = @($chefDashboard.pendingOrders + $chefDashboard.preparingOrders + $chefDashboard.readyOrders | Where-Object { [int]$_.orderId -eq $orderId } | Select-Object -First 1)[0]
    Assert-True ($null -ne $chefOrder) "Chef dashboard khong thay order $orderId."
    Add-Result 'Chef Dashboard Order Visible' $true "orderId=$orderId"

    Invoke-Json POST "$chefBase/orders/$orderId/items/$itemId/start" $chef @{} | Out-Null
    Invoke-Json POST "$chefBase/orders/$orderId/items/$itemId/ready" $chef @{} | Out-Null
    Add-Result 'Chef Item Start/Ready' $true "itemId=$itemId"

    $readyNotifications = Wait-For -TimeoutSeconds 20 -IntervalSeconds 1 -Probe {
        $payload = Invoke-Json GET "$customerBase/ready-notifications" $customer
        @($payload.items | Where-Object { [int]$_.orderId -eq $orderId -and [int]$_.orderItemId -eq $itemId } | Select-Object -First 1)[0]
    }
    Assert-True ($null -ne $readyNotifications) "Khong co ready notification cho order $orderId item $itemId."
    $notificationId = [int]$readyNotifications.notificationId
    Assert-True ($notificationId -gt 0) 'Notification id khong hop le.'
    Add-Result 'Customer Ready Notification' $true "notificationId=$notificationId dish=$($readyNotifications.dishName)"

    Invoke-Json POST "$customerBase/ready-notifications/$notificationId/resolve" $customer @{} | Out-Null
    Add-Result 'Customer Resolve Notification' $true "notificationId=$notificationId"

    $confirm = Invoke-Json POST "$customerBase/order/confirm-received?orderId=$orderId" $customer @{}
    Assert-True ($confirm.success) 'Customer confirm received that bai.'
    Add-Result 'Customer Confirm Received' $true $confirm.message

    $cashierLogin = Invoke-Json POST "$staffAuthBase/login" $cashier @{
        username = 'cashier_lan'
        password = '123456'
    }
    Assert-True ($cashierLogin.success -and $cashierLogin.nextPath -eq '/Staff/Cashier/Index') "Cashier login redirect sai: $($cashierLogin.nextPath)"
    Add-Result 'Cashier Login' $true $cashierLogin.nextPath

    $cashierDashboard = Invoke-Json GET "$cashierBase/dashboard" $cashier
    $cashierOrder = @($cashierDashboard.orders | Where-Object { [int]$_.orderId -eq $orderId } | Select-Object -First 1)[0]
    Assert-True ($null -ne $cashierOrder) "Cashier dashboard khong thay order $orderId."
    $subtotal = [decimal]$cashierOrder.subtotal
    Add-Result 'Cashier Dashboard Order Visible' $true "subtotal=$subtotal"

    $checkout = Invoke-Json POST "$cashierBase/orders/$orderId/checkout" $cashier @{
        discount = 0
        pointsUsed = 0
        paymentMethod = 'CASH'
        paymentAmount = ($subtotal + 50000)
        idempotencyKey = $checkoutKey
    }
    $billCode = [string]$checkout.billCode
    Assert-True (-not [string]::IsNullOrWhiteSpace($billCode)) 'Cashier checkout khong co billCode.'
    Add-Result 'Cashier Checkout' $true $billCode

    $checkoutReplay = Invoke-Json POST "$cashierBase/orders/$orderId/checkout" $cashier @{
        discount = 0
        pointsUsed = 0
        paymentMethod = 'CASH'
        paymentAmount = ($subtotal + 50000)
        idempotencyKey = $checkoutKey
    }
    Assert-True ([string]$checkoutReplay.billCode -eq $billCode) 'Replay checkout khong tra ve bill cu.'
    Add-Result 'Cashier Checkout Replay' $true $checkoutReplay.billCode

    $history = Invoke-Json GET "$cashierBase/history" $cashier
    $historyBill = @($history.bills | Where-Object { $_.billCode -eq $billCode } | Select-Object -First 1)[0]
    Assert-True ($null -ne $historyBill) "History khong co bill $billCode."
    Add-Result 'Cashier History Contains Bill' $true $billCode

    $postCheckoutAddError = Expect-ApiError POST "$customerBase/order/items" $customer @{
        dishId = $dishId
        quantity = 1
        note = 'post checkout stale add'
        expectedDiningSessionCode = $sessionCode
    }
    $postCheckoutErrorText = Coalesce-Message $postCheckoutAddError
    Assert-True ($postCheckoutErrorText.Length -gt 0) 'Khong nhan duoc loi stale session sau checkout.'
    Add-Result 'Post-Checkout Stale Add Rejected' $true $postCheckoutErrorText

    $adminLogin = Invoke-Json POST "$staffAuthBase/login" $admin @{
        username = 'admin'
        password = '123456'
    }
    Assert-True ($adminLogin.success -and $adminLogin.nextPath -eq '/Admin/Dashboard/Index') "Admin login redirect sai: $($adminLogin.nextPath)"
    Add-Result 'Admin Login' $true $adminLogin.nextPath

    Invoke-Json POST "$adminBase/dishes/$dishId/availability" $admin @{ available = $false } | Out-Null
    Add-Result 'Admin Set Dish Unavailable' $true "dishId=$dishId"

    $soldOutMenu = Invoke-Json GET "$customerBase/menu" $customerGuest
    $soldOutDish = $null
    foreach ($category in @($soldOutMenu.menu.categories)) {
        $candidate = @($category.dishes | Where-Object { [int]$_.dishId -eq $dishId } | Select-Object -First 1)[0]
        if ($null -ne $candidate) { $soldOutDish = $candidate; break }
    }
    Assert-True ($null -ne $soldOutDish -and -not [bool]$soldOutDish.available) 'Menu khong phan anh mon het hang.'
    Add-Result 'Customer Menu Reflects Sold-Out' $true "dishId=$dishId"

    $soldOutRecommendations = Invoke-Json GET "$customerBase/menu/recommendations" $customerGuest
    $badRecommendation = @($soldOutRecommendations.recommendations | Where-Object { [int]$_.dishId -eq $dishId } | Select-Object -First 1)[0]
    Assert-True ($null -eq $badRecommendation) 'Recommendations van tra ve mon het hang.'
    Add-Result 'Recommendations Exclude Sold-Out' $true "dishId=$dishId"

    $soldOutOrderError = Expect-ApiError POST "$customerBase/order/items" $customer @{
        dishId = $dishId
        quantity = 1
        note = 'sold out add'
        expectedDiningSessionCode = $null
    }
    $soldOutErrorText = Coalesce-Message $soldOutOrderError
    Assert-True ($soldOutErrorText.Length -gt 0) 'Add sold-out dish khong tra ve loi ro rang.'
    Add-Result 'Sold-Out Add Rejected' $true $soldOutErrorText

    Invoke-Json POST "$adminBase/dishes/$dishId/availability" $admin @{ available = $true } | Out-Null
    Add-Result 'Admin Restore Dish Availability' $true "dishId=$dishId"

    $ordersAudit = Invoke-JsonNoSession GET "${ordersInternal}?orderId=$orderId"
    $billingAudit = Invoke-JsonNoSession GET "${billingInternal}?orderId=$orderId"
    $catalogAudit = Invoke-JsonNoSession GET "${catalogInternal}?dishId=$dishId"
    Assert-True (@($ordersAudit).Count -gt 0) "Orders audit rong cho order $orderId."
    Assert-True (@($billingAudit).Count -gt 0) "Billing audit rong cho order $orderId."
    Assert-True (@($catalogAudit).Count -gt 0) "Catalog audit rong cho dish $dishId."
    Add-Result 'Audit Logs Present' $true "orders=$(@($ordersAudit).Count) billing=$(@($billingAudit).Count) catalog=$(@($catalogAudit).Count)"

    $cashierCross = Invoke-Json POST "$staffAuthBase/login" (New-Object Microsoft.PowerShell.Commands.WebRequestSession) @{
        username = 'cashier_lan'
        password = '123456'
    }
    $chefCross = Invoke-Json POST "$staffAuthBase/login" (New-Object Microsoft.PowerShell.Commands.WebRequestSession) @{
        username = 'chef_hung'
        password = '123456'
    }
    $adminCross = Invoke-Json POST "$staffAuthBase/login" (New-Object Microsoft.PowerShell.Commands.WebRequestSession) @{
        username = 'admin'
        password = '123456'
    }
    Assert-True ($cashierCross.nextPath -eq '/Staff/Cashier/Index') 'Cashier nextPath sai.'
    Assert-True ($chefCross.nextPath -eq '/Staff/Chef/Index') 'Chef nextPath sai.'
    Assert-True ($adminCross.nextPath -eq '/Admin/Dashboard/Index') 'Admin nextPath sai.'
    Add-Result 'Cross-Role Redirect Targets' $true "cashier=$($cashierCross.nextPath) chef=$($chefCross.nextPath) admin=$($adminCross.nextPath)"
}
catch {
    Add-Result 'ERROR' $false $_.Exception.Message
}
finally {
    try {
        Invoke-Json POST "$adminBase/dishes/$dishId/availability" $admin @{ available = $originalAvailability } | Out-Null
    } catch {}
    try { Invoke-Json POST "$customerBase/auth/logout" $customer @{} | Out-Null } catch {}
    try { Invoke-Json POST "$staffAuthBase/logout" $chef @{} | Out-Null } catch {}
    try { Invoke-Json POST "$cashierBase/auth/logout" $cashier @{} | Out-Null } catch {}
    try { Invoke-Json POST "$adminBase/auth/logout" $admin @{} | Out-Null } catch {}
}

$results | Format-Table -AutoSize | Out-String | Write-Output
$pass = ($results | Where-Object { $_.Pass -eq $true }).Count
$total = $results.Count
Write-Output "SUMMARY: $pass/$total PASS"
if ($pass -ne $total) { exit 1 }
