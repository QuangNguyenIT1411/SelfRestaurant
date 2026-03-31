param(
    [string]$BaseUrl = 'http://localhost:5100',
    [string]$CatalogApi = 'http://localhost:5101',
    [string]$OrdersApi = 'http://localhost:5102',
    [int]$BranchId = 1,
    [string]$CustomerUsername = 'minh.tran',
    [string]$CustomerPassword = '123456',
    [string]$CustomerPhone = '0987654321',
    [string]$ChefUsername = 'chef_hung',
    [string]$ChefPassword = '123456',
    [string]$CashierUsername = 'cashier_lan',
    [string]$CashierPassword = '123456'
)

$ErrorActionPreference = 'Stop'

$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$logPath = ".runlogs/actor_chain_microservice_$timestamp.log"
$summaryPath = ".runlogs/actor_chain_microservice_summary_$timestamp.json"
$latestPath = ".runlogs/actor_chain_microservice_summary_latest.json"
$results = New-Object System.Collections.Generic.List[object]

function Write-Log([string]$msg) {
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg
    Write-Host $line
    Add-Content -Path $logPath -Value $line
}

function Add-Result([string]$step, [bool]$pass, [string]$detail) {
    $results.Add([pscustomobject]@{
        step = $step
        pass = $pass
        detail = $detail
    }) | Out-Null

    $state = if ($pass) { 'PASS' } else { 'FAIL' }
    Write-Log "[$state] $step :: $detail"
}

function Get-Token([string]$html) {
    $patterns = @(
        'name="__RequestVerificationToken"[^>]*value="([^"]+)"',
        "name='__RequestVerificationToken'[^>]*value='([^']+)'",
        'value="([^"]+)"[^>]*name="__RequestVerificationToken"'
    )

    foreach ($p in $patterns) {
        $m = [regex]::Match($html, $p, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($m.Success) { return $m.Groups[1].Value }
    }

    throw 'No anti-forgery token found.'
}

function To-JsonObj($response) {
    $content = if ($null -eq $response.Content) { '' } else { [string]$response.Content }
    $content = $content.Trim()
    if ([string]::IsNullOrWhiteSpace($content)) {
        return [pscustomobject]@{ success = $false; raw = '' }
    }

    $candidates = @($content)
    $start = $content.IndexOf('{')
    $end = $content.LastIndexOf('}')
    if ($start -ge 0 -and $end -gt $start) {
        $slice = $content.Substring($start, $end - $start + 1)
        if ($slice -ne $content) { $candidates += $slice }
    }

    foreach ($candidate in $candidates) {
        try { return ($candidate | ConvertFrom-Json) } catch { }
    }

    return [pscustomobject]@{ success = $false; raw = $content }
}

function Get-PropValue {
    param(
        [Parameter(Mandatory = $true)][object]$Object,
        [Parameter(Mandatory = $true)][string[]]$CandidateNames
    )
    foreach ($name in $CandidateNames) {
        $prop = $Object.PSObject.Properties | Where-Object { $_.Name -ieq $name } | Select-Object -First 1
        if ($null -ne $prop) { return $prop.Value }
    }
    return $null
}

function Ensure-JsonSuccess {
    param(
        [Parameter(Mandatory = $true)]$Json,
        [Parameter(Mandatory = $true)][string]$Context
    )

    $ok = Get-PropValue -Object $Json -CandidateNames @('success', 'Success')
    if (-not [bool]$ok) {
        $msg = Get-PropValue -Object $Json -CandidateNames @('message', 'Message', 'raw')
        throw "$Context failed: $msg"
    }
}

function Get-OrderStatusCode([object]$json) {
    $order = Get-PropValue -Object $json -CandidateNames @('order')
    if ($null -ne $order) {
        $code = Get-PropValue -Object $order -CandidateNames @('statusCode', 'StatusCode')
        if ($null -ne $code) { return "$code".Trim().ToUpperInvariant() }
    }

    $code2 = Get-PropValue -Object $json -CandidateNames @('statusCode', 'StatusCode')
    if ($null -ne $code2) { return "$code2".Trim().ToUpperInvariant() }

    return ''
}

function Parse-Int([string]$text) {
    $digits = [regex]::Replace($text, '[^\d]', '')
    if ([string]::IsNullOrWhiteSpace($digits)) { return 0 }
    return [int]$digits
}

function Get-CustomerPoints {
    param(
        [Parameter(Mandatory = $true)][string]$BaseUrl,
        [Parameter(Mandatory = $true)]$Session
    )

    $dash = Invoke-WebRequest "$BaseUrl/Customer/Dashboard" -WebSession $Session -UseBasicParsing
    $html = [string]$dash.Content

    $m1 = [regex]::Match($html, 'Points:\s*([0-9\.,]+)', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if ($m1.Success) { return (Parse-Int $m1.Groups[1].Value) }

    $m2 = [regex]::Match($html, '(Điểm|Diem)[^0-9]*([0-9\.,]+)', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if ($m2.Success) { return (Parse-Int $m2.Groups[2].Value) }

    return 0
}

function Save-Summary([int]$orderId, [int]$tableId, [int]$pointsBefore, [int]$pointsAfter) {
    $passed = ($results | Where-Object { $_.pass }).Count
    $failed = $results.Count - $passed
    $summary = [pscustomobject]@{
        timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        total = $results.Count
        passed = $passed
        failed = $failed
        orderId = $orderId
        tableId = $tableId
        pointsBefore = $pointsBefore
        pointsAfter = $pointsAfter
        results = $results
    }

    $json = $summary | ConvertTo-Json -Depth 20
    $json | Set-Content -Encoding UTF8 $summaryPath
    $json | Set-Content -Encoding UTF8 $latestPath

    Write-Host "SUMMARY_TOTAL=$($summary.total)"
    Write-Host "SUMMARY_PASSED=$($summary.passed)"
    Write-Host "SUMMARY_FAILED=$($summary.failed)"
    Write-Host "SUMMARY_JSON=$summaryPath"

    return $summary
}

$customerSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$chefSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$cashierSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession

$orderId = 0
$tableId = 0
$pointsBefore = 0
$pointsAfter = 0

try {
    foreach ($url in @("$CatalogApi/healthz", "$OrdersApi/healthz", "$BaseUrl/")) {
        $h = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 5
        if ($h.StatusCode -lt 200 -or $h.StatusCode -ge 400) { throw "$url status $($h.StatusCode)" }
    }
    Add-Result 'Health Check' $true 'gateway + catalog + orders reachable'
}
catch {
    Add-Result 'Health Check' $false $_.Exception.Message
    $summary = Save-Summary $orderId $tableId $pointsBefore $pointsAfter
    exit 1
}

try {
    $loginPage = Invoke-WebRequest "$BaseUrl/Customer/Login?mode=login&force=true" -WebSession $customerSession -UseBasicParsing
    $token = Get-Token $loginPage.Content
    $loginResp = Invoke-WebRequest "$BaseUrl/Customer/Login" -Method Post -WebSession $customerSession -UseBasicParsing -Headers @{ 'X-Requested-With' = 'XMLHttpRequest' } -Body @{
        __RequestVerificationToken = $token
        mode = 'login'
        'Login.Username' = $CustomerUsername
        'Login.Password' = $CustomerPassword
        'Login.ReturnUrl' = ''
    }
    $loginJson = To-JsonObj $loginResp
    Ensure-JsonSuccess -Json $loginJson -Context 'Customer login'
    Add-Result 'Customer Login' $true $CustomerUsername
}
catch {
    Add-Result 'Customer Login' $false $_.Exception.Message
}

try {
    $pointsBefore = Get-CustomerPoints -BaseUrl $BaseUrl -Session $customerSession
    Add-Result 'Customer Points Before' $true "points=$pointsBefore"
}
catch {
    Add-Result 'Customer Points Before' $false $_.Exception.Message
}

try {
    $tbResp = Invoke-WebRequest "$BaseUrl/Home/GetBranchTables?branchId=$BranchId" -WebSession $customerSession -UseBasicParsing
    $tbJson = To-JsonObj $tbResp
    Ensure-JsonSuccess -Json $tbJson -Context 'GetBranchTables'

    $tables = @($tbJson.tables)
    if ($tables.Count -eq 0) { throw 'No tables returned' }
    $picked = $tables | Where-Object { $_.isAvailable -eq $true } | Select-Object -First 1
    if ($null -eq $picked) { $picked = $tables | Select-Object -First 1 }
    $tableId = [int]$picked.tableId

    Add-Result 'Pick Table' ($tableId -gt 0) "branch=$BranchId table=$tableId"
}
catch {
    Add-Result 'Pick Table' $false $_.Exception.Message
}

try {
    Invoke-WebRequest "$OrdersApi/api/tables/$tableId/reset" -Method Post -UseBasicParsing | Out-Null
    Add-Result 'Reset Table Before Flow' $true "tableId=$tableId"
}
catch {
    Add-Result 'Reset Table Before Flow' $false $_.Exception.Message
}

$dishId = 0
try {
    $menuResp = Invoke-WebRequest "$CatalogApi/api/branches/$BranchId/menu" -UseBasicParsing
    $menu = $menuResp.Content | ConvertFrom-Json
    foreach ($cat in $menu.categories) {
        $d = @($cat.dishes | Where-Object { $_.available -eq $true }) | Select-Object -First 1
        if ($null -ne $d) {
            $dishId = [int]$d.dishId
            break
        }
    }
    if ($dishId -le 0) { throw 'No available dish found' }
    Add-Result 'Pick Dish' $true "dishId=$dishId"
}
catch {
    Add-Result 'Pick Dish' $false $_.Exception.Message
}

try {
    $addResp = Invoke-WebRequest "$OrdersApi/api/tables/$tableId/order/items" -Method Post -UseBasicParsing -ContentType 'application/json' -Body (@{
        dishId = $dishId
        quantity = 2
        note = "actor-chain-$timestamp"
    } | ConvertTo-Json)
    $addJson = To-JsonObj $addResp
    $orderId = [int](Get-PropValue -Object $addJson -CandidateNames @('orderId', 'OrderId'))
    if ($orderId -le 0) { throw "Missing orderId. raw=$($addResp.Content)" }
    Add-Result 'Customer Create Order' $true "orderId=$orderId tableId=$tableId"
}
catch {
    Add-Result 'Customer Create Order' $false $_.Exception.Message
}

try {
    $scanResp = Invoke-WebRequest "$BaseUrl/Order/ScanLoyaltyCard" -Method Post -WebSession $customerSession -UseBasicParsing -ContentType 'application/json' -Body (@{
        tableId = $tableId
        phoneNumber = $CustomerPhone
    } | ConvertTo-Json)
    $scanJson = To-JsonObj $scanResp
    Ensure-JsonSuccess -Json $scanJson -Context 'Customer ScanLoyaltyCard'
    Add-Result 'Customer Scan Loyalty Card' $true "phone=$CustomerPhone"
}
catch {
    Add-Result 'Customer Scan Loyalty Card' $false $_.Exception.Message
}

try {
    $sendResp = Invoke-WebRequest "$BaseUrl/Order/SendToKitchen" -Method Post -WebSession $customerSession -UseBasicParsing -ContentType 'application/json' -Body (@{
        tableId = $tableId
    } | ConvertTo-Json)
    $sendJson = To-JsonObj $sendResp
    Ensure-JsonSuccess -Json $sendJson -Context 'Customer SendToKitchen'
    Add-Result 'Customer Send To Kitchen' $true "orderId=$orderId"
}
catch {
    Add-Result 'Customer Send To Kitchen' $false $_.Exception.Message
}

try {
    $loginPage = Invoke-WebRequest "$BaseUrl/Staff/Account/Login" -WebSession $chefSession -UseBasicParsing
    $token = Get-Token $loginPage.Content
    $loginResp = Invoke-WebRequest "$BaseUrl/Staff/Account/Login" -Method Post -WebSession $chefSession -UseBasicParsing -Headers @{ 'X-Requested-With' = 'XMLHttpRequest' } -Body @{
        __RequestVerificationToken = $token
        username = $ChefUsername
        password = $ChefPassword
        rememberMe = 'false'
    }
    if ($loginResp.StatusCode -notin 200, 302) { throw "status $($loginResp.StatusCode)" }
    Add-Result 'Chef Login' $true $ChefUsername
}
catch {
    Add-Result 'Chef Login' $false $_.Exception.Message
}

try {
    $prepResp = Invoke-WebRequest "$BaseUrl/Staff/Chef/UpdateOrderStatus" -Method Post -WebSession $chefSession -UseBasicParsing -ContentType 'application/x-www-form-urlencoded' -Body @{
        orderId = $orderId
        statusCode = 'PREPARING'
    }
    $prepJson = To-JsonObj $prepResp
    Ensure-JsonSuccess -Json $prepJson -Context 'Chef PREPARING'

    Start-Sleep -Milliseconds 250
    $statusResp = Invoke-WebRequest "$BaseUrl/Home/GetOrderStatus?orderId=$orderId" -WebSession $customerSession -UseBasicParsing
    $statusJson = To-JsonObj $statusResp
    Ensure-JsonSuccess -Json $statusJson -Context 'Customer read PREPARING'
    $statusCode = Get-OrderStatusCode $statusJson
    Add-Result 'Chef -> Customer PREPARING' ($statusCode -eq 'PREPARING') "status=$statusCode"
}
catch {
    Add-Result 'Chef -> Customer PREPARING' $false $_.Exception.Message
}

try {
    $readyResp = Invoke-WebRequest "$BaseUrl/Staff/Chef/UpdateOrderStatus" -Method Post -WebSession $chefSession -UseBasicParsing -ContentType 'application/x-www-form-urlencoded' -Body @{
        orderId = $orderId
        statusCode = 'READY'
    }
    $readyJson = To-JsonObj $readyResp
    Ensure-JsonSuccess -Json $readyJson -Context 'Chef READY'

    Start-Sleep -Milliseconds 250
    $statusResp = Invoke-WebRequest "$BaseUrl/Home/GetOrderStatus?orderId=$orderId" -WebSession $customerSession -UseBasicParsing
    $statusJson = To-JsonObj $statusResp
    Ensure-JsonSuccess -Json $statusJson -Context 'Customer read READY'
    $statusCode = Get-OrderStatusCode $statusJson
    Add-Result 'Chef -> Customer READY' ($statusCode -eq 'READY') "status=$statusCode"
}
catch {
    Add-Result 'Chef -> Customer READY' $false $_.Exception.Message
}

try {
    $loginPage = Invoke-WebRequest "$BaseUrl/Staff/Account/Login" -WebSession $cashierSession -UseBasicParsing
    $token = Get-Token $loginPage.Content
    $loginResp = Invoke-WebRequest "$BaseUrl/Staff/Account/Login" -Method Post -WebSession $cashierSession -UseBasicParsing -Headers @{ 'X-Requested-With' = 'XMLHttpRequest' } -Body @{
        __RequestVerificationToken = $token
        username = $CashierUsername
        password = $CashierPassword
        rememberMe = 'false'
    }
    if ($loginResp.StatusCode -notin 200, 302) { throw "status $($loginResp.StatusCode)" }
    Add-Result 'Cashier Login' $true $CashierUsername
}
catch {
    Add-Result 'Cashier Login' $false $_.Exception.Message
}

try {
    $payResp = Invoke-WebRequest "$BaseUrl/Staff/Cashier/ProcessPayment" -Method Post -WebSession $cashierSession -UseBasicParsing -ContentType 'application/json' -Body (@{
        OrderID = $orderId
        Discount = 0
        PointsUsed = 0
        PaymentMethod = 'CASH'
        PaymentAmount = 1000000
    } | ConvertTo-Json)
    $payJson = To-JsonObj $payResp
    Ensure-JsonSuccess -Json $payJson -Context 'Cashier ProcessPayment'
    $pointsEarned = [int](Get-PropValue -Object $payJson -CandidateNames @('pointsEarned', 'PointsEarned'))
    Add-Result 'Cashier Process Payment' $true "orderId=$orderId pointsEarned=$pointsEarned"
}
catch {
    Add-Result 'Cashier Process Payment' $false $_.Exception.Message
}

try {
    Start-Sleep -Milliseconds 300
    $statusResp = Invoke-WebRequest "$BaseUrl/Home/GetOrderStatus?orderId=$orderId" -WebSession $customerSession -UseBasicParsing
    $statusJson = To-JsonObj $statusResp
    Ensure-JsonSuccess -Json $statusJson -Context 'Customer read COMPLETED'
    $statusCode = Get-OrderStatusCode $statusJson
    Add-Result 'Cashier -> Customer COMPLETED' ($statusCode -eq 'COMPLETED') "status=$statusCode"
}
catch {
    Add-Result 'Cashier -> Customer COMPLETED' $false $_.Exception.Message
}

try {
    $pointsAfter = Get-CustomerPoints -BaseUrl $BaseUrl -Session $customerSession
    $increased = ($pointsAfter -gt $pointsBefore)
    Add-Result 'Customer Points Increased After Payment' $increased "before=$pointsBefore after=$pointsAfter"
}
catch {
    Add-Result 'Customer Points Increased After Payment' $false $_.Exception.Message
}

try {
    Invoke-WebRequest "$OrdersApi/api/tables/$tableId/reset" -Method Post -UseBasicParsing | Out-Null
    Add-Result 'Reset Table After Flow' $true "tableId=$tableId"
}
catch {
    Add-Result 'Reset Table After Flow' $false $_.Exception.Message
}

$summary = Save-Summary $orderId $tableId $pointsBefore $pointsAfter
if ($summary.failed -gt 0) { exit 1 }
