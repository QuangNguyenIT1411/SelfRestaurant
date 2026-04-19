$ErrorActionPreference = 'Stop'

$base = 'http://localhost:5100'
$customerBase = "$base/api/gateway/customer"
$chefBase = "$base/api/gateway/staff"
$cashierBase = "$base/api/gateway/staff/cashier"
$adminBase = "$base/api/gateway/admin"
$summaryPath = 'C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main\.runlogs\gateway_account_routes_current_summary.json'

$results = New-Object System.Collections.Generic.List[object]

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
        $payload = [System.Text.Encoding]::UTF8.GetBytes($json)
        return Invoke-RestMethod -Method $Method -Uri $Uri -WebSession $Session -TimeoutSec 60 -ContentType 'application/json; charset=utf-8' -Body $payload
    }
    catch {
        throw "$(Get-ErrorBody $_)"
    }
}

function Invoke-Page {
    param(
        [string]$Uri,
        [Microsoft.PowerShell.Commands.WebRequestSession]$Session
    )

    return Invoke-WebRequest -Uri $Uri -WebSession $Session -UseBasicParsing -TimeoutSec 60
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
        try {
            return $raw | ConvertFrom-Json
        }
        catch {
            throw "Khong parse duoc error body: $raw"
        }
    }
}

$customerSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$chefSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$cashierSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$adminSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession

$stamp = Get-Date -Format 'yyyyMMddHHmmss'
$customerUsername = "acct_$stamp"
$customerPassword1 = 'Pass@123'
$customerPassword2 = 'Pass@456'
$customerPassword3 = 'Pass@789'
$customerPhone1 = '09' + $stamp.Substring($stamp.Length - 8)
$customerPhone2 = '08' + $stamp.Substring($stamp.Length - 8)
$customerEmail1 = "$customerUsername@example.com"
$customerEmail2 = "$customerUsername.updated@example.com"
$customerUsername2 = "${customerUsername}_u"
$customerName2 = "Tai khoan test $stamp"

$branchId = $null
$tableId = $null

$chefOriginal = $null
$cashierOriginal = $null
$adminOriginal = $null

$chefPasswordCurrent = '123456'
$cashierPasswordCurrent = '123456'
$adminPasswordCurrent = '123456'

$chefPasswordTemp = 'Temp@Chef123'
$cashierPasswordTemp = 'Temp@Cash123'
$adminPasswordTemp = 'Temp@Admin123'

try {
    $health = Invoke-WebRequest "$base/healthz" -UseBasicParsing -TimeoutSec 20
    Assert-True ($health.StatusCode -eq 200) 'Gateway health check failed.'
    Add-Result 'Gateway Health' $true '200'

    $branches = Invoke-Json GET "$customerBase/branches" $customerSession
    $preferredBranch = $branches | Where-Object { [int]$_.branchId -eq 1 } | Select-Object -First 1
    if ($null -eq $preferredBranch) {
        $preferredBranch = $branches | Select-Object -First 1
    }
    $branchId = [int]$preferredBranch.branchId
    $tables = Invoke-Json GET "$customerBase/branches/$branchId/tables" $customerSession
    $preferredTable = $tables.tables | Where-Object { $_.isAvailable } | Select-Object -First 1
    if ($null -eq $preferredTable) {
        $preferredTable = $tables.tables | Select-Object -First 1
    }
    $tableId = [int]$preferredTable.tableId
    Add-Result 'Customer Branch/Table Seed' $true "branchId=$branchId tableId=$tableId"

    $register = Invoke-Json POST "$customerBase/auth/register" $customerSession @{
        name = "Account Route $stamp"
        username = $customerUsername
        password = $customerPassword1
        phoneNumber = $customerPhone1
        email = $customerEmail1
        gender = 'Nam'
        dateOfBirth = '2000-01-01'
        address = 'Ho Chi Minh'
    }
    Assert-True ($register.success) 'Customer register that bai.'
    Add-Result 'Customer Register' $true $customerUsername

    $customerLogin1 = Invoke-Json POST "$customerBase/auth/login" $customerSession @{
        username = $customerUsername
        password = $customerPassword1
    }
    Assert-True ($customerLogin1.success) 'Customer login lan 1 that bai.'
    Assert-True ($customerLogin1.nextPath -eq '/Home/Index') "Customer login redirect sai: $($customerLogin1.nextPath)"
    Add-Result 'Customer Login Route' $true $customerLogin1.nextPath

    $customerProfile1 = Invoke-Json GET "$customerBase/profile" $customerSession
    Assert-True ($customerProfile1.username -eq $customerUsername) 'Customer profile ban dau sai username.'
    Add-Result 'Customer Profile Load' $true "customerId=$($customerProfile1.customerId)"

    $customerProfileUpdated = Invoke-Json PUT "$customerBase/profile" $customerSession @{
        username = $customerUsername2
        name = $customerName2
        phoneNumber = $customerPhone2
        email = $customerEmail2
        gender = 'Nam'
        dateOfBirth = '2000-01-01'
        address = 'Quan 1'
    }
    Assert-True ($customerProfileUpdated.username -eq $customerUsername2) 'Customer update profile khong doi username.'
    Assert-True ($customerProfileUpdated.phoneNumber -eq $customerPhone2) 'Customer update profile khong doi phone.'
    Add-Result 'Customer Update Profile' $true $customerProfileUpdated.username

    $customerSessionDto = Invoke-Json GET "$customerBase/session" $customerSession
    Assert-True ($customerSessionDto.customer.username -eq $customerUsername2) 'Customer session khong dong bo username moi.'
    Add-Result 'Customer Session Sync After Profile Update' $true $customerSessionDto.customer.username

    $customerMismatch = Expect-ApiError POST "$customerBase/auth/change-password" $customerSession @{
        currentPassword = $customerPassword1
        newPassword = $customerPassword2
        confirmPassword = 'khong_khop'
    }
    Assert-True ($customerMismatch.code -eq 'password_mismatch') "Customer mismatch code sai: $($customerMismatch.code)"
    Add-Result 'Customer Change Password Validation' $true $customerMismatch.code

    $customerChange1 = Invoke-Json POST "$customerBase/auth/change-password" $customerSession @{
        currentPassword = $customerPassword1
        newPassword = $customerPassword2
        confirmPassword = $customerPassword2
    }
    Assert-True ($customerChange1.success) 'Customer doi mat khau that bai.'
    Add-Result 'Customer Change Password' $true $customerChange1.message

    $customerLogout1 = Invoke-Json POST "$customerBase/auth/logout" $customerSession @{}
    Assert-True ($customerLogout1.nextPath -eq '/Home/Index') "Customer logout redirect sai: $($customerLogout1.nextPath)"
    Add-Result 'Customer Logout Route' $true $customerLogout1.nextPath

    $customerLogin2 = Invoke-Json POST "$customerBase/auth/login" $customerSession @{
        username = $customerUsername2
        password = $customerPassword2
    }
    Assert-True ($customerLogin2.success) 'Customer login bang mat khau moi that bai.'
    Add-Result 'Customer Login With Changed Password' $true $customerLogin2.nextPath

    $forgot = Invoke-Json POST "$customerBase/auth/forgot-password" $customerSession @{
        usernameOrEmailOrPhone = $customerUsername2
    }
    Assert-True (-not [string]::IsNullOrWhiteSpace($forgot.resetToken)) 'Customer forgot password khong tra resetToken.'
    Assert-True ($forgot.resetPath -like '/Customer/ResetPassword*') "Customer forgot password resetPath sai: $($forgot.resetPath)"
    Add-Result 'Customer Forgot Password' $true $forgot.resetPath

    $reset = Invoke-Json POST "$customerBase/auth/reset-password" $customerSession @{
        token = $forgot.resetToken
        newPassword = $customerPassword3
        confirmPassword = $customerPassword3
    }
    Assert-True ($reset.success) 'Customer reset password that bai.'
    Assert-True ($reset.nextPath -eq '/Customer/Login') "Customer reset nextPath sai: $($reset.nextPath)"
    Add-Result 'Customer Reset Password' $true $reset.nextPath

    Invoke-Json POST "$customerBase/auth/logout" $customerSession @{} | Out-Null
    $customerLogin3 = Invoke-Json POST "$customerBase/auth/login" $customerSession @{
        username = $customerUsername2
        password = $customerPassword3
    }
    Assert-True ($customerLogin3.success) 'Customer login bang mat khau reset that bai.'
    Add-Result 'Customer Login With Reset Password' $true $customerLogin3.nextPath

    $setContext = Invoke-Json POST "$customerBase/context/table" $customerSession @{
        branchId = $branchId
        tableId = $tableId
    }
    Assert-True ([int]$setContext.tableId -eq $tableId) 'Customer set context that bai.'
    Add-Result 'Customer Set Context' $true "tableId=$($setContext.tableId)"

    Invoke-Json POST "$customerBase/auth/logout" $customerSession @{} | Out-Null
    $customerLogin4 = Invoke-Json POST "$customerBase/auth/login" $customerSession @{
        username = $customerUsername2
        password = $customerPassword3
    }
    Assert-True ($customerLogin4.nextPath -eq '/Menu/Index') "Customer relogin with context redirect sai: $($customerLogin4.nextPath)"
    Add-Result 'Customer Context Redirect After Relogin' $true $customerLogin4.nextPath

    foreach ($route in @('/Home/Index', '/Home/About', '/Home/Contact', '/Menu/Index', '/Order/Index', '/Customer/Dashboard', '/Customer/Orders')) {
        $page = Invoke-Page "$base$route" $customerSession
        Assert-True ($page.StatusCode -eq 200) "Customer route $route khong mo duoc."
        Add-Result "Customer Route $route" $true '200'
    }

    $chefLogin = Invoke-Json POST "$chefBase/auth/login" $chefSession @{
        username = 'chef_hung'
        password = $chefPasswordCurrent
    }
    Assert-True ($chefLogin.nextPath -eq '/Staff/Chef/Index') "Chef login redirect sai: $($chefLogin.nextPath)"
    Add-Result 'Chef Login Route' $true $chefLogin.nextPath

    $chefDashboard = Invoke-Json GET "$chefBase/chef/dashboard" $chefSession
    $chefOriginal = [pscustomobject]@{
        Name = [string]$chefDashboard.staff.name
        Phone = [string]$chefDashboard.staff.phone
        Email = [string]$chefDashboard.staff.email
    }
    $chefUpdated = Invoke-Json PUT "$chefBase/chef/account" $chefSession @{
        name = $chefOriginal.Name
        phone = '0905111222'
        email = 'hung.chef+qa@selfrestaurant.com'
    }
    Assert-True ($chefUpdated.phone -eq '0905111222') 'Chef update account khong doi phone.'
    Add-Result 'Chef Update Account' $true $chefUpdated.phone

    $chefMismatch = Expect-ApiError POST "$chefBase/chef/change-password" $chefSession @{
        currentPassword = $chefPasswordCurrent
        newPassword = $chefPasswordTemp
        confirmPassword = 'sai'
    }
    Assert-True ($chefMismatch.code -eq 'password_mismatch') "Chef mismatch code sai: $($chefMismatch.code)"
    Add-Result 'Chef Change Password Validation' $true $chefMismatch.code

    $chefChange1 = Invoke-Json POST "$chefBase/chef/change-password" $chefSession @{
        currentPassword = $chefPasswordCurrent
        newPassword = $chefPasswordTemp
        confirmPassword = $chefPasswordTemp
    }
    Assert-True ($chefChange1.success) 'Chef doi mat khau that bai.'
    $chefPasswordCurrent = $chefPasswordTemp
    Add-Result 'Chef Change Password' $true $chefChange1.message

    Invoke-Json POST "$chefBase/auth/logout" $chefSession @{} | Out-Null
    $chefRelogin = Invoke-Json POST "$chefBase/auth/login" $chefSession @{
        username = 'chef_hung'
        password = $chefPasswordCurrent
    }
    Assert-True ($chefRelogin.success) 'Chef login bang mat khau moi that bai.'
    Add-Result 'Chef Login With Changed Password' $true $chefRelogin.nextPath

    foreach ($route in @('/app/chef/Staff/Account/Login', '/app/chef/Staff/Chef/Index', '/app/chef/Staff/Chef/History')) {
        $page = Invoke-Page "$base$route" $chefSession
        Assert-True ($page.StatusCode -eq 200) "Chef route $route khong mo duoc."
        Add-Result "Chef Route $route" $true '200'
    }

    $cashierLogin = Invoke-Json POST "$cashierBase/auth/login" $cashierSession @{
        username = 'cashier_lan'
        password = $cashierPasswordCurrent
    }
    Assert-True ($cashierLogin.nextPath -eq '/Staff/Cashier/Index') "Cashier login redirect sai: $($cashierLogin.nextPath)"
    Add-Result 'Cashier Login Route' $true $cashierLogin.nextPath

    $cashierHistory = Invoke-Json GET "$cashierBase/history?take=5" $cashierSession
    $cashierOriginal = [pscustomobject]@{
        Name = [string]$cashierHistory.account.name
        Phone = [string]$cashierHistory.account.phone
        Email = [string]$cashierHistory.account.email
    }
    $cashierUpdated = Invoke-Json PUT "$cashierBase/account" $cashierSession @{
        name = $cashierOriginal.Name
        phone = '0905222333'
        email = 'lan.cashier+qa@selfrestaurant.com'
    }
    Assert-True ($cashierUpdated.phone -eq '0905222333') 'Cashier update account khong doi phone.'
    Add-Result 'Cashier Update Account' $true $cashierUpdated.phone

    $cashierMismatch = Expect-ApiError POST "$cashierBase/change-password" $cashierSession @{
        currentPassword = $cashierPasswordCurrent
        newPassword = $cashierPasswordTemp
        confirmPassword = 'sai'
    }
    Assert-True ($cashierMismatch.code -eq 'password_mismatch') "Cashier mismatch code sai: $($cashierMismatch.code)"
    Add-Result 'Cashier Change Password Validation' $true $cashierMismatch.code

    $cashierChange1 = Invoke-Json POST "$cashierBase/change-password" $cashierSession @{
        currentPassword = $cashierPasswordCurrent
        newPassword = $cashierPasswordTemp
        confirmPassword = $cashierPasswordTemp
    }
    Assert-True ($cashierChange1.success) 'Cashier doi mat khau that bai.'
    $cashierPasswordCurrent = $cashierPasswordTemp
    Add-Result 'Cashier Change Password' $true $cashierChange1.message

    Invoke-Json POST "$cashierBase/auth/logout" $cashierSession @{} | Out-Null
    $cashierRelogin = Invoke-Json POST "$cashierBase/auth/login" $cashierSession @{
        username = 'cashier_lan'
        password = $cashierPasswordCurrent
    }
    Assert-True ($cashierRelogin.success) 'Cashier login bang mat khau moi that bai.'
    Add-Result 'Cashier Login With Changed Password' $true $cashierRelogin.nextPath

    foreach ($route in @('/app/cashier/Staff/Account/Login', '/app/cashier/Staff/Cashier/Index', '/app/cashier/Staff/Cashier/History', '/app/cashier/Staff/Cashier/Report')) {
        $page = Invoke-Page "$base$route" $cashierSession
        Assert-True ($page.StatusCode -eq 200) "Cashier route $route khong mo duoc."
        Add-Result "Cashier Route $route" $true '200'
    }

    $adminLogin = Invoke-Json POST "$adminBase/auth/login" $adminSession @{
        username = 'admin'
        password = $adminPasswordCurrent
    }
    Assert-True ($adminLogin.nextPath -eq '/Admin/Dashboard/Index') "Admin login redirect sai: $($adminLogin.nextPath)"
    Add-Result 'Admin Login Route' $true $adminLogin.nextPath

    $adminSettings = Invoke-Json GET "$adminBase/settings" $adminSession
    $adminOriginal = [pscustomobject]@{
        Name = [string]$adminSettings.name
        Phone = [string]$adminSettings.phone
        Email = [string]$adminSettings.email
    }
    $adminUpdated = Invoke-Json PUT "$adminBase/settings" $adminSession @{
        name = $adminOriginal.Name
        phone = '0905333444'
        email = 'admin+qa@selfrestaurant.com'
    }
    Assert-True ($adminUpdated.phone -eq '0905333444') 'Admin update settings khong doi phone.'
    Add-Result 'Admin Update Settings' $true $adminUpdated.phone

    $adminMismatch = Expect-ApiError POST "$adminBase/settings/change-password" $adminSession @{
        currentPassword = $adminPasswordCurrent
        newPassword = $adminPasswordTemp
        confirmPassword = 'sai'
    }
    Assert-True ($adminMismatch.code -eq 'password_mismatch') "Admin mismatch code sai: $($adminMismatch.code)"
    Add-Result 'Admin Change Password Validation' $true $adminMismatch.code

    $adminChange1 = Invoke-Json POST "$adminBase/settings/change-password" $adminSession @{
        currentPassword = $adminPasswordCurrent
        newPassword = $adminPasswordTemp
        confirmPassword = $adminPasswordTemp
    }
    Assert-True ($adminChange1.success) 'Admin doi mat khau that bai.'
    $adminPasswordCurrent = $adminPasswordTemp
    Add-Result 'Admin Change Password' $true $adminChange1.message

    Invoke-Json POST "$adminBase/auth/logout" $adminSession @{} | Out-Null
    $adminRelogin = Invoke-Json POST "$adminBase/auth/login" $adminSession @{
        username = 'admin'
        password = $adminPasswordCurrent
    }
    Assert-True ($adminRelogin.success) 'Admin login bang mat khau moi that bai.'
    Add-Result 'Admin Login With Changed Password' $true $adminRelogin.nextPath

    foreach ($route in @('/app/admin/Admin/Account/Login', '/app/admin/Admin/Dashboard/Index', '/app/admin/Admin/Employees/Index', '/app/admin/Admin/Customers/Index', '/app/admin/Admin/Reports/Revenue', '/app/admin/Admin/Settings/Index')) {
        $page = Invoke-Page "$base$route" $adminSession
        Assert-True ($page.StatusCode -eq 200) "Admin route $route khong mo duoc."
        Add-Result "Admin Route $route" $true '200'
    }
}
catch {
    Add-Result 'Gateway Account/Route Current' $false $_.Exception.Message
}
finally {
    try {
        if ($null -ne $chefOriginal) {
            Invoke-Json PUT "$chefBase/chef/account" $chefSession @{
                name = $chefOriginal.Name
                phone = $chefOriginal.Phone
                email = $chefOriginal.Email
            } | Out-Null
        }
    } catch {}

    try {
        if ($chefPasswordCurrent -ne '123456') {
            Invoke-Json POST "$chefBase/chef/change-password" $chefSession @{
                currentPassword = $chefPasswordCurrent
                newPassword = '123456'
                confirmPassword = '123456'
            } | Out-Null
            $chefPasswordCurrent = '123456'
        }
    } catch {}

    try { Invoke-Json POST "$chefBase/auth/logout" $chefSession @{} | Out-Null } catch {}

    try {
        if ($null -ne $cashierOriginal) {
            Invoke-Json PUT "$cashierBase/account" $cashierSession @{
                name = $cashierOriginal.Name
                phone = $cashierOriginal.Phone
                email = $cashierOriginal.Email
            } | Out-Null
        }
    } catch {}

    try {
        if ($cashierPasswordCurrent -ne '123456') {
            Invoke-Json POST "$cashierBase/change-password" $cashierSession @{
                currentPassword = $cashierPasswordCurrent
                newPassword = '123456'
                confirmPassword = '123456'
            } | Out-Null
            $cashierPasswordCurrent = '123456'
        }
    } catch {}

    try { Invoke-Json POST "$cashierBase/auth/logout" $cashierSession @{} | Out-Null } catch {}

    try {
        if ($null -ne $adminOriginal) {
            Invoke-Json PUT "$adminBase/settings" $adminSession @{
                name = $adminOriginal.Name
                phone = $adminOriginal.Phone
                email = $adminOriginal.Email
            } | Out-Null
        }
    } catch {}

    try {
        if ($adminPasswordCurrent -ne '123456') {
            Invoke-Json POST "$adminBase/settings/change-password" $adminSession @{
                currentPassword = $adminPasswordCurrent
                newPassword = '123456'
                confirmPassword = '123456'
            } | Out-Null
            $adminPasswordCurrent = '123456'
        }
    } catch {}

    try { Invoke-Json POST "$adminBase/auth/logout" $adminSession @{} | Out-Null } catch {}

    try { Invoke-Json POST "$customerBase/auth/logout" $customerSession @{} | Out-Null } catch {}
}

$resultItems = @($results.ToArray())
$summary = [pscustomobject]@{
    total = $resultItems.Count
    passed = @($resultItems | Where-Object { $_.pass -eq $true }).Count
    failed = @($resultItems | Where-Object { $_.pass -ne $true }).Count
    customerUsername = $customerUsername2
    branchId = $branchId
    tableId = $tableId
    results = $resultItems
}

$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding UTF8

if ($summary.failed -gt 0) {
    exit 1
}

Write-Host "PASS account-routes customer=$($summary.customerUsername) branch=$branchId table=$tableId"
