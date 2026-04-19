$ErrorActionPreference = 'Stop'

$base = 'http://localhost:5100'
$customerBase = "$base/api/gateway/customer"
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$results = New-Object System.Collections.Generic.List[object]
$stamp = Get-Date -Format 'yyyyMMddHHmmss'
$username = "resetctx_$stamp"
$password = 'Pass@123'
$phone = '09' + $stamp.Substring($stamp.Length - 8)

function Add-Result([string]$Step, [bool]$Pass, [string]$Detail) {
    $results.Add([pscustomobject]@{
        step = $Step
        pass = $Pass
        detail = $Detail
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

try {
    $branches = Invoke-Json GET "$customerBase/branches" $session
    $branch = $branches | Select-Object -First 1
    $tables = Invoke-Json GET "$customerBase/branches/$($branch.branchId)/tables" $session
    $table = $tables.tables | Where-Object { $_.isAvailable } | Select-Object -First 1
    if ($null -eq $table) {
        $table = $tables.tables | Select-Object -First 1
    }

    $register = Invoke-Json POST "$customerBase/auth/register" $session @{
        name = "Reset Context $stamp"
        username = $username
        password = $password
        phoneNumber = $phone
        email = "$username@example.com"
        gender = 'Nam'
        dateOfBirth = '2000-01-01'
        address = 'Ho Chi Minh'
    }
    Add-Result 'Register Customer' ([bool]$register.success) $username

    $login1 = Invoke-Json POST "$customerBase/auth/login" $session @{
        username = $username
        password = $password
    }
    Add-Result 'Login Without Context' ($login1.nextPath -eq '/Home/Index') $login1.nextPath

    $setContext = Invoke-Json POST "$customerBase/context/table" $session @{
        branchId = [int]$branch.branchId
        tableId = [int]$table.tableId
    }
    Add-Result 'Set Table Context' ([int]$setContext.tableId -eq [int]$table.tableId) "tableId=$($setContext.tableId)"

    $logout1 = Invoke-Json POST "$customerBase/auth/logout" $session @{}
    Add-Result 'Logout After Set Context' ($logout1.nextPath -eq '/Home/Index') $logout1.nextPath

    $login2 = Invoke-Json POST "$customerBase/auth/login" $session @{
        username = $username
        password = $password
    }
    Add-Result 'Login With Context' ($login2.nextPath -eq '/Menu/Index') $login2.nextPath

    $clearContext = Invoke-Json DELETE "$customerBase/context/table" $session
    $clearDetail = if ($null -ne $clearContext -and -not [string]::IsNullOrWhiteSpace([string]$clearContext.message)) { [string]$clearContext.message } else { 'cleared' }
    Add-Result 'Clear Table Context' ([bool]$clearContext.success) $clearDetail

    $logout2 = Invoke-Json POST "$customerBase/auth/logout" $session @{}
    Add-Result 'Logout After Clear Context' ($logout2.nextPath -eq '/Home/Index') $logout2.nextPath

    $login3 = Invoke-Json POST "$customerBase/auth/login" $session @{
        username = $username
        password = $password
    }
    Add-Result 'Relogin After Clear Context' ($login3.nextPath -eq '/Home/Index') $login3.nextPath

    $homeResponse = Invoke-WebRequest "$base/Home/Index" -WebSession $session -UseBasicParsing -TimeoutSec 30
    Add-Result 'Home Route' ($homeResponse.StatusCode -eq 200) '200'
}
catch {
    Add-Result 'Reset Table From Home' $false $_.Exception.Message
    exit 1
}

$pass = ($results | Where-Object { $_.pass }).Count
$total = $results.Count
Write-Output "SUMMARY: $pass/$total PASS"
