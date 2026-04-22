$ErrorActionPreference = 'Stop'

$base = 'http://localhost:5100'
$admin = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$customer = New-Object Microsoft.PowerShell.Commands.WebRequestSession

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

    if ($null -eq $Body) {
        return Invoke-RestMethod -Method $Method -Uri $Uri -WebSession $Session -TimeoutSec 60
    }

    $json = $Body | ConvertTo-Json -Depth 20
    $payload = [System.Text.Encoding]::UTF8.GetBytes($json)
    return Invoke-RestMethod -Method $Method -Uri $Uri -WebSession $Session -TimeoutSec 60 -ContentType 'application/json; charset=utf-8' -Body $payload
}

Invoke-Json POST "$base/api/gateway/customer/dev/reset-test-state" $customer @{} | Out-Null
Invoke-Json POST "$base/api/gateway/staff/auth/login" $admin @{
    username = 'admin'
    password = '123456'
} | Out-Null

$branches = Invoke-Json GET "$base/api/gateway/customer/branches" $customer
$branchId = [int](@($branches | Select-Object -First 1)[0].branchId)
$tables = Invoke-Json GET "$base/api/gateway/customer/branches/$branchId/tables" $customer
$table = @($tables.tables | Where-Object { $_.statusCode -ne 'OCCUPIED' } | Select-Object -First 1)[0]
if ($null -eq $table) { $table = @($tables.tables | Select-Object -First 1)[0] }
$tableId = [int]$table.tableId

Invoke-Json POST "$base/api/gateway/customer/context/table" $customer @{
    tableId = $tableId
    branchId = $branchId
} | Out-Null

$menu = Invoke-Json GET "$base/api/gateway/customer/menu" $customer
$dish = $null
foreach ($category in @($menu.menu.categories)) {
    $candidate = @($category.dishes | Where-Object { $_.available } | Select-Object -First 1)[0]
    if ($null -ne $candidate) { $dish = $candidate; break }
}
if ($null -eq $dish) { throw 'No orderable dish found.' }
$dishId = [int]$dish.dishId

$stamp = Get-Date -Format 'yyyyMMddHHmmss'
$username = "soldout_$stamp"
Invoke-Json POST "$base/api/gateway/customer/auth/register" $customer @{
    name = 'Sold Out QA'
    username = $username
    password = 'Pass@123'
    phoneNumber = '09' + $stamp.Substring($stamp.Length - 8)
    email = "$username@example.com"
    gender = 'Nam'
    address = 'HCM'
} | Out-Null
Invoke-Json POST "$base/api/gateway/customer/auth/login" $customer @{
    username = $username
    password = 'Pass@123'
} | Out-Null
Invoke-Json POST "$base/api/gateway/customer/context/table" $customer @{
    tableId = $tableId
    branchId = $branchId
} | Out-Null

Invoke-Json POST "$base/api/gateway/admin/dishes/$dishId/availability" $admin @{
    available = $false
} | Out-Null

try {
    Invoke-Json POST "$base/api/gateway/customer/order/items" $customer @{
        dishId = $dishId
        quantity = 1
        note = 'soldout-check'
        expectedDiningSessionCode = $null
    } | Out-Null

    throw 'UNEXPECTED_SUCCESS'
}
catch {
    $body = Get-ErrorBody $_
    Write-Output $body
}
finally {
    try {
        Invoke-Json POST "$base/api/gateway/admin/dishes/$dishId/availability" $admin @{
            available = $true
        } | Out-Null
    }
    catch {}
}
