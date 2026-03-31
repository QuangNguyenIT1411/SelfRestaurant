$ErrorActionPreference = 'Stop'

function Add-Result($name, $ok, $detail) {
    $script:results += [pscustomobject]@{
        ChucNang = $name
        Pass = [bool]$ok
        ChiTiet = $detail
    }
}

function Tok([string]$h) {
    $ps = @(
        'name="__RequestVerificationToken"[^>]*value="([^"]+)"',
        "name='__RequestVerificationToken'[^>]*value='([^']+)'",
        'value="([^"]+)"[^>]*name="__RequestVerificationToken"'
    )
    foreach ($p in $ps) {
        $m = [regex]::Match($h, $p, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($m.Success) { return $m.Groups[1].Value }
    }
    throw 'No token'
}

function Post-Form($url, $body, $session, $ajax = $false) {
    $headers = @{}
    if ($ajax) { $headers['X-Requested-With'] = 'XMLHttpRequest' }
    Invoke-WebRequest $url -Method Post -WebSession $session -Body $body -Headers $headers -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing
}

function To-JsonObj($response) {
    $content = if ($null -eq $response.Content) { '' } else { [string]$response.Content }
    $content = $content.Trim()
    if ([string]::IsNullOrWhiteSpace($content)) { return [pscustomobject]@{ success = $false; raw = '' } }
    try { return ($content | ConvertFrom-Json) } catch { return [pscustomobject]@{ success = $false; raw = $content } }
}

function Process-PaymentJson($root, $session, $orderId, $method, $amount) {
    $resp = Invoke-WebRequest "$root/Staff/Cashier/ProcessPayment" -Method Post -WebSession $session -UseBasicParsing -ContentType 'application/json' -Body (@{
        OrderID = $orderId
        Discount = 0
        PointsUsed = 0
        PaymentMethod = $method
        PaymentAmount = $amount
    } | ConvertTo-Json)
    return (To-JsonObj $resp)
}

function New-OrderForCashier($ordersApi, $tableId, $dishId, $note) {
    try {
        Invoke-WebRequest "$ordersApi/api/tables/$tableId/reset" -Method Post -UseBasicParsing | Out-Null
    }
    catch {
        throw "Reset table $tableId failed: $($_.Exception.Message)"
    }

    try {
        Invoke-WebRequest "$ordersApi/api/tables/$tableId/occupy" -Method Post -UseBasicParsing -ContentType 'application/json' -Body '{}' | Out-Null
    }
    catch {
        throw "Occupy table $tableId failed: $($_.Exception.Message)"
    }

    try {
        Invoke-WebRequest "$ordersApi/api/tables/$tableId/order/items" -Method Post -UseBasicParsing -ContentType 'application/json' -Body (@{ dishId = $dishId; quantity = 1; note = $note } | ConvertTo-Json) | Out-Null
    }
    catch {
        throw "Add item table $tableId failed: $($_.Exception.Message)"
    }

    try {
        Invoke-WebRequest "$ordersApi/api/tables/$tableId/order/submit" -Method Post -UseBasicParsing -ContentType 'application/json' -Body '{}' | Out-Null
    }
    catch {
        throw "Submit table $tableId failed: $($_.Exception.Message)"
    }

    try {
        $active = Invoke-WebRequest "$ordersApi/api/tables/$tableId/order" -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
    }
    catch {
        throw "Read active order table $tableId failed: $($_.Exception.Message)"
    }
    return [int]$active.orderId
}

$results = @()
$root = 'http://localhost:5100'
$catalog = 'http://localhost:5101'
$orders = 'http://localhost:5102'
$billing = 'http://localhost:5105'
$branchId = 1
$cashierUser = 'cashier_lan'
$cashierPass = '123456'
$tempPass = 'Temp@789'
$staff = New-Object Microsoft.PowerShell.Commands.WebRequestSession

try {
    # Login
    $loginPage = Invoke-WebRequest "$root/Staff/Account/Login" -WebSession $staff -UseBasicParsing
    $loginToken = Tok $loginPage.Content
    $loginResp = Post-Form "$root/Staff/Account/Login" @{
        username = $cashierUser
        password = $cashierPass
        __RequestVerificationToken = $loginToken
    } $staff
    Add-Result 'Dang nhap Cashier' ($loginResp.StatusCode -in 200, 302) "status=$($loginResp.StatusCode)"

    # Pages
    $indexPage = Invoke-WebRequest "$root/Staff/Cashier" -WebSession $staff -UseBasicParsing
    Add-Result 'Mo trang thanh toan' ($indexPage.StatusCode -eq 200) "status=$($indexPage.StatusCode)"
    $historyPage = Invoke-WebRequest "$root/Staff/Cashier/History" -WebSession $staff -UseBasicParsing
    Add-Result 'Mo trang lich su' ($historyPage.StatusCode -eq 200) "status=$($historyPage.StatusCode)"
    $reportPage = Invoke-WebRequest "$root/Staff/Cashier/Report" -WebSession $staff -UseBasicParsing
    Add-Result 'Mo trang bao cao' ($reportPage.StatusCode -eq 200) "status=$($reportPage.StatusCode)"

    # Date filters
    $today = (Get-Date).ToString('yyyy-MM-dd')
    $historyFilter = Invoke-WebRequest "$root/Staff/Cashier/History?date=$today" -WebSession $staff -UseBasicParsing
    Add-Result 'Loc lich su theo ngay' ($historyFilter.StatusCode -eq 200) "date=$today"
    $reportFilter = Invoke-WebRequest "$root/Staff/Cashier/Report?date=$today" -WebSession $staff -UseBasicParsing
    Add-Result 'Loc bao cao theo ngay' ($reportFilter.StatusCode -eq 200) "date=$today"

    # Prepare dish and tables
    $menuApi = Invoke-WebRequest "$catalog/api/branches/$branchId/menu" -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
    $dish = $null
    foreach ($c in $menuApi.categories) {
        $dish = $c.dishes | Where-Object { $_.available -eq $true } | Select-Object -First 1
        if ($dish) { break }
    }
    if ($null -eq $dish) { throw 'No available dish for cashier test' }
    $dishId = [int]$dish.dishId
    Add-Result 'Lay mon de test checkout' ($dishId -gt 0) "dishId=$dishId"

    $tables = Invoke-WebRequest "$catalog/api/branches/$branchId/tables" -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
    $avail = @($tables.tables | Where-Object { $_.isAvailable -eq $true })
    if ($avail.Count -lt 3) { $avail = @($tables.tables) }
    if ($avail.Count -lt 3) { throw 'Need at least 3 tables for cashier test' }
    Add-Result 'Lay ban de test checkout' ($avail.Count -ge 3) "count=$($avail.Count)"

    # Insufficient cash
    $order1 = New-OrderForCashier $orders ([int]$avail[0].tableId) $dishId 'cashier-insufficient'
    $insufficient = Process-PaymentJson $root $staff $order1 'CASH' 1
    Add-Result 'Checkout loi tien mat khong du' (-not [bool]$insufficient.success) "orderId=$order1"

    # Invalid payment method
    $invalidMethod = Process-PaymentJson $root $staff $order1 'BADMETHOD' 999999
    Add-Result 'Checkout loi payment method sai' (-not [bool]$invalidMethod.success) "orderId=$order1"

    # Success cash
    $okCash = Process-PaymentJson $root $staff $order1 'CASH' 999999
    Start-Sleep -Milliseconds 300
    $queueAfterCash = Invoke-WebRequest "$billing/api/branches/$branchId/cashier/orders" -UseBasicParsing | Select-Object -ExpandProperty Content
    $removed1 = ([bool]$okCash.success) -and (-not ($queueAfterCash -match ('\"orderId\":' + $order1)))
    Add-Result 'Checkout thanh cong CASH' $removed1 "orderId=$order1"

    # Success card
    $order2 = New-OrderForCashier $orders ([int]$avail[1].tableId) $dishId 'cashier-card'
    $okCard = Process-PaymentJson $root $staff $order2 'CARD' 0
    Start-Sleep -Milliseconds 300
    $queueAfterCard = Invoke-WebRequest "$billing/api/branches/$branchId/cashier/orders" -UseBasicParsing | Select-Object -ExpandProperty Content
    $removed2 = ([bool]$okCard.success) -and (-not ($queueAfterCard -match ('\"orderId\":' + $order2)))
    Add-Result 'Checkout thanh cong CARD' $removed2 "orderId=$order2"

    # Success transfer
    $order3 = New-OrderForCashier $orders ([int]$avail[2].tableId) $dishId 'cashier-transfer'
    $okTransfer = Process-PaymentJson $root $staff $order3 'TRANSFER' 0
    Start-Sleep -Milliseconds 300
    $queueAfterTransfer = Invoke-WebRequest "$billing/api/branches/$branchId/cashier/orders" -UseBasicParsing | Select-Object -ExpandProperty Content
    $removed3 = ([bool]$okTransfer.success) -and (-not ($queueAfterTransfer -match ('\"orderId\":' + $order3)))
    Add-Result 'Checkout thanh cong TRANSFER' $removed3 "orderId=$order3"

    # History/report content
    $histAfter = Invoke-WebRequest "$root/Staff/Cashier/History" -WebSession $staff -UseBasicParsing
    Add-Result 'Lich su co hoa don sau checkout' ($histAfter.Content -match 'BILL-') 'BILL marker'
    $repAfter = Invoke-WebRequest "$root/Staff/Cashier/Report" -WebSession $staff -UseBasicParsing
    Add-Result 'Bao cao hien thi du lieu' ($repAfter.Content -match 'BILL-' -or $repAfter.Content -match 'Total' -or $repAfter.Content -match 'table') 'report html'

    # Update account and revert
    $origName = 'Thu ngan Lan'
    $newName = 'Thu ngan Lan QA'
    $u1 = Post-Form "$root/Staff/Cashier/UpdateAccount" @{ name = $newName; email = 'lan.cashier@selfrestaurant.com'; phone = '0903333333' } $staff $true
    $u1j = To-JsonObj $u1
    Add-Result 'Cap nhat tai khoan Cashier' ([bool]$u1j.success) "name=$newName"
    Post-Form "$root/Staff/Cashier/UpdateAccount" @{ name = $origName; email = 'lan.cashier@selfrestaurant.com'; phone = '0903333333' } $staff $true | Out-Null

    # Change password mismatch
    $cpBad = Post-Form "$root/Staff/Cashier/ChangePassword" @{ currentPassword = $cashierPass; newPassword = 'Xyz@123'; confirmPassword = 'DIFF@123' } $staff $true
    $cpBadJson = To-JsonObj $cpBad
    Add-Result 'Doi mat khau sai xac nhan bi chan' (-not [bool]$cpBadJson.success) 'mismatch blocked'

    # Change password success and revert
    $cpOk = Post-Form "$root/Staff/Cashier/ChangePassword" @{ currentPassword = $cashierPass; newPassword = $tempPass; confirmPassword = $tempPass } $staff $true
    $cpOkJson = To-JsonObj $cpOk
    Add-Result 'Doi mat khau thanh cong' ([bool]$cpOkJson.success) 'temp pass set'

    $sTemp = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    $lp2 = Invoke-WebRequest "$root/Staff/Account/Login" -WebSession $sTemp -UseBasicParsing
    $lt2 = Tok $lp2.Content
    $lr2 = Post-Form "$root/Staff/Account/Login" @{ username = $cashierUser; password = $tempPass; __RequestVerificationToken = $lt2 } $sTemp
    Add-Result 'Dang nhap bang mat khau moi' ($lr2.StatusCode -in 200, 302) "status=$($lr2.StatusCode)"

    $revert = Post-Form "$root/Staff/Cashier/ChangePassword" @{ currentPassword = $tempPass; newPassword = $cashierPass; confirmPassword = $cashierPass } $sTemp $true
    $rvJson = To-JsonObj $revert
    Add-Result 'Khoi phuc mat khau cu' ([bool]$rvJson.success) 'restored'
}
catch {
    Add-Result 'ERROR' $false $_.Exception.Message
}

$results | Format-Table -AutoSize | Out-String | Write-Output
$pass = ($results | Where-Object { $_.Pass -eq $true }).Count
$total = $results.Count
Write-Output "SUMMARY: $pass/$total PASS"
