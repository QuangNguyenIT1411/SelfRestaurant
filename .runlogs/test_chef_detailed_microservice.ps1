$ErrorActionPreference = 'Stop'

$base = 'http://localhost:5100'
$catalog = 'http://localhost:5101'
$orders = 'http://localhost:5102'
$staffBase = "$base/api/gateway/staff"
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$results = New-Object System.Collections.Generic.List[object]
$chefUser = 'chef_hung'
$chefPasswordCurrent = '123456'
$chefPasswordTemp = 'Temp@Chef123'
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

function Find-AvailableTable([int]$BranchId) {
    $tables = Invoke-RestMethod -Method GET -Uri "$catalog/api/branches/$BranchId/tables" -TimeoutSec 60
    $table = $tables.tables | Where-Object { $_.isAvailable } | Select-Object -First 1
    if ($null -eq $table) {
        $table = $tables.tables | Select-Object -First 1
    }
    return $table
}

function New-TestOrder([int]$BranchId, [int]$DishId, [string]$Note) {
    $table = Find-AvailableTable $BranchId
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
        ItemId = [int]($active.items | Select-Object -First 1).itemId
    }
}

try {
    Invoke-JsonNoSession POST "$base/api/gateway/customer/dev/reset-test-state" @{} | Out-Null
    Add-Result 'Reset test state' $true 'ok'

    $login = Invoke-Json POST "$staffBase/auth/login" $session @{
        username = $chefUser
        password = $chefPasswordCurrent
    }
    Add-Result 'Dang nhap Chef' ([bool]$login.success -and $login.nextPath -eq '/Staff/Chef/Index') $login.nextPath

    foreach ($route in @('/app/chef/Staff/Account/Login', '/app/chef/Staff/Chef/Index', '/app/chef/Staff/Chef/History')) {
        $page = Invoke-WebRequest "$base$route" -WebSession $session -UseBasicParsing -TimeoutSec 30
        Add-Result "Route $route" ($page.StatusCode -eq 200) '200'
    }

    $dashboard = Invoke-Json GET "$staffBase/chef/dashboard" $session
    $menu = Invoke-Json GET "$staffBase/chef/menu" $session
    $history = Invoke-Json GET "$staffBase/chef/history?take=20" $session
    Add-Result 'Dashboard Chef' ($null -ne $dashboard.staff) "branchId=$($dashboard.staff.branchId)"
    Add-Result 'Menu Chef' (@($menu.dishes).Count -gt 0) "count=$(@($menu.dishes).Count)"
    Add-Result 'History Chef' ($null -ne $history) "count=$(@($history).Count)"

    $originalProfile = [pscustomobject]@{
        Name = [string]$dashboard.staff.name
        Phone = [string]$dashboard.staff.phone
        Email = [string]$dashboard.staff.email
    }

    $dishWithIngredients = $null
    foreach ($dish in @($menu.dishes | Where-Object { $_.available } | Select-Object -First 12)) {
        try {
            $ing = Invoke-Json GET "$staffBase/chef/dishes/$($dish.dishId)/ingredients" $session
            if (@($ing.items).Count -gt 0) {
                $dishWithIngredients = [pscustomobject]@{
                    Dish = $dish
                    Ingredients = $ing
                }
                break
            }
        }
        catch {}
    }
    if ($null -eq $dishWithIngredients) {
        throw 'Khong tim thay mon trong menu co nguyen lieu de test chef.'
    }

    $dishId = [int]$dishWithIngredients.Dish.dishId
    Add-Result 'Mon co nguyen lieu' ($dishId -gt 0) "dishId=$dishId ingredients=$(@($dishWithIngredients.Ingredients.items).Count)"

    $order1 = New-TestOrder -BranchId ([int]$dashboard.staff.branchId) -DishId $dishId -Note 'chef-detailed-flow'
    Add-Result 'Tao don test Chef' ($order1.OrderId -gt 0 -and $order1.ItemId -gt 0) "orderId=$($order1.OrderId) itemId=$($order1.ItemId)"

    $noteResp = Invoke-Json PATCH "$staffBase/chef/orders/$($order1.OrderId)/items/$($order1.ItemId)/note" $session @{
        note = 'Chef detailed note'
        append = $false
    }
    Add-Result 'Sua ghi chu mon' ([bool]$noteResp.success) $noteResp.message

    $startResp = Invoke-Json POST "$staffBase/chef/orders/$($order1.OrderId)/start" $session @{}
    $readyResp = Invoke-Json POST "$staffBase/chef/orders/$($order1.OrderId)/ready" $session @{}
    Add-Result 'Bat dau che bien' ([bool]$startResp.success) $startResp.message
    Add-Result 'Danh dau san sang' ([bool]$readyResp.success) $readyResp.message

    $order2 = New-TestOrder -BranchId ([int]$dashboard.staff.branchId) -DishId $dishId -Note 'chef-cancel-flow'
    $cancelResp = Invoke-Json POST "$staffBase/chef/orders/$($order2.OrderId)/items/$($order2.ItemId)/cancel" $session @{
        reason = 'Het nguyen lieu tam thoi'
    }
    Add-Result 'Huy mon Chef' ([bool]$cancelResp.success) $cancelResp.message

    $ingredientResp = Invoke-Json GET "$staffBase/chef/dishes/$dishId/ingredients" $session
    Add-Result 'Xem nguyen lieu mon' (@($ingredientResp.items).Count -gt 0) "count=$(@($ingredientResp.items).Count)"

    $firstIngredient = @($ingredientResp.items)[0]
    $saveIngredientResp = Invoke-Json PUT "$staffBase/chef/dishes/$dishId/ingredients" $session @{
        items = @(
            @{
                ingredientId = [int]$firstIngredient.ingredientId
                quantityPerDish = 1.23
            }
        )
    }
    $savedLine = @($saveIngredientResp.items | Where-Object { [int]$_.ingredientId -eq [int]$firstIngredient.ingredientId }) | Select-Object -First 1
    $qtyOk = $null -ne $savedLine -and [math]::Abs([decimal]$savedLine.quantityPerDish - [decimal]1.23) -lt [decimal]0.01
    Add-Result 'Luu nguyen lieu mon' $qtyOk "ingredientId=$($firstIngredient.ingredientId)"

    $hideResp = Invoke-Json POST "$staffBase/chef/dishes/$dishId/availability" $session @{ available = $false }
    $showResp = Invoke-Json POST "$staffBase/chef/dishes/$dishId/availability" $session @{ available = $true }
    Add-Result 'Tam ngung ban mon' ([bool]$hideResp.success -and -not [bool]$hideResp.available) $hideResp.message
    Add-Result 'Mo ban lai mon' ([bool]$showResp.success -and [bool]$showResp.available) $showResp.message

    $updateProfileResp = Invoke-Json PUT "$staffBase/chef/account" $session @{
        name = 'Hung Chef QA'
        phone = '0905111222'
        email = 'hung.chef+qa@selfrestaurant.com'
    }
    Add-Result 'Cap nhat tai khoan Chef' ($updateProfileResp.phone -eq '0905111222') $updateProfileResp.phone

    $mismatch = Expect-ApiError POST "$staffBase/chef/change-password" $session @{
        currentPassword = $chefPasswordCurrent
        newPassword = $chefPasswordTemp
        confirmPassword = 'sai'
    }
    Add-Result 'Chan sai xac nhan mat khau' ($mismatch.code -eq 'password_mismatch') $mismatch.code

    $changeResp = Invoke-Json POST "$staffBase/chef/change-password" $session @{
        currentPassword = $chefPasswordCurrent
        newPassword = $chefPasswordTemp
        confirmPassword = $chefPasswordTemp
    }
    $chefPasswordCurrent = $chefPasswordTemp
    Add-Result 'Doi mat khau Chef' ([bool]$changeResp.success) $changeResp.message

    Invoke-Json POST "$staffBase/auth/logout" $session @{} | Out-Null
    $relogin = Invoke-Json POST "$staffBase/auth/login" $session @{
        username = $chefUser
        password = $chefPasswordCurrent
    }
    Add-Result 'Dang nhap bang mat khau moi' ([bool]$relogin.success) $relogin.nextPath
}
catch {
    Add-Result 'ERROR' $false $_.Exception.Message
}
finally {
    try {
        if ($null -ne $originalProfile) {
            Invoke-Json PUT "$staffBase/chef/account" $session @{
                name = $originalProfile.Name
                phone = $originalProfile.Phone
                email = $originalProfile.Email
            } | Out-Null
        }
    } catch {}

    try {
        if ($chefPasswordCurrent -ne '123456') {
            Invoke-Json POST "$staffBase/chef/change-password" $session @{
                currentPassword = $chefPasswordCurrent
                newPassword = '123456'
                confirmPassword = '123456'
            } | Out-Null
            $chefPasswordCurrent = '123456'
        }
    } catch {}

    try { Invoke-Json POST "$staffBase/auth/logout" $session @{} | Out-Null } catch {}
}

$results | Format-Table -AutoSize | Out-String | Write-Output
$pass = ($results | Where-Object { $_.Pass -eq $true }).Count
$total = $results.Count
Write-Output "SUMMARY: $pass/$total PASS"
if ($pass -ne $total) { exit 1 }
