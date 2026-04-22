$ErrorActionPreference='Stop'
function Read-ErrorResponse($Exception) {
    $response = $Exception.Response
    if ($null -eq $response) { return [pscustomobject]@{ raw = $Exception.Message; status = 0; json = $null } }
    $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
    $raw = $reader.ReadToEnd(); $reader.Close()
    $json = $null
    if (-not [string]::IsNullOrWhiteSpace($raw)) { try { $json = $raw | ConvertFrom-Json } catch {} }
    [pscustomobject]@{ raw = $raw; status = [int]$response.StatusCode; json = $json }
}
function Invoke-RestApi {
    param([string]$Method='GET',[string]$Url,$Session,$Body=$null)
    $params = @{ Uri=$Url; Method=$Method; TimeoutSec=60 }
    if ($null -ne $Session) { $params.WebSession = $Session }
    if ($null -ne $Body) { $params.ContentType='application/json'; $params.Body=($Body|ConvertTo-Json -Depth 20) }
    try {
        $json = Invoke-RestMethod @params
        return [pscustomobject]@{ ok=$true; status=200; json=$json }
    } catch {
        $err = Read-ErrorResponse $_.Exception
        return [pscustomobject]@{ ok=$false; status=$err.status; json=$err.json; raw=$err.raw }
    }
}
$base='http://localhost:5100'
$catalog='http://localhost:5101'
$adminSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$customerSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$cashierSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$healthUrls = @('http://localhost:5100/healthz','http://localhost:5101/healthz','http://localhost:5102/healthz','http://localhost:5103/healthz','http://localhost:5104/healthz','http://localhost:5105/healthz')
$health = @()
foreach ($url in $healthUrls) { $resp = Invoke-RestApi -Url $url; $health += [pscustomobject]@{ url=$url; ok=$resp.ok; status=$resp.status } }
$report = [ordered]@{}
$report.health = $health
$report.adminLogin = Invoke-RestApi -Method POST -Url "$base/api/gateway/admin/auth/login" -Session $adminSession -Body @{ username='admin'; password='123456' }
$report.adminIngredients = Invoke-RestApi -Url "$base/api/gateway/admin/ingredients?search=&page=1&pageSize=10&includeInactive=true" -Session $adminSession
$report.adminDishes = Invoke-RestApi -Url "$base/api/gateway/admin/dishes?search=&page=1&pageSize=10" -Session $adminSession
$report.adminTables = Invoke-RestApi -Url "$base/api/gateway/admin/tables?search=&page=1&pageSize=10" -Session $adminSession
$report.customerLogin = Invoke-RestApi -Method POST -Url "$base/api/gateway/customer/auth/login" -Session $customerSession -Body @{ username='lan.nguyen'; password='123456' }
$report.customerBranches = Invoke-RestApi -Url "$base/api/gateway/customer/branches" -Session $customerSession
$report.cashierLogin = Invoke-RestApi -Method POST -Url "$base/api/gateway/staff/cashier/auth/login" -Session $cashierSession -Body @{ username='cashier_lan'; password='123456' }
$report.cashierDashboard = Invoke-RestApi -Url "$base/api/gateway/staff/cashier/dashboard" -Session $cashierSession
$report.branch1Tables = Invoke-RestApi -Url "$catalog/api/branches/1/tables"
$report.branch1TableStatus = @($report.branch1Tables.json.tables | Where-Object { $_.tableId -in @(1,2,3) } | Select-Object tableId, isAvailable, statusCode, statusName)
$report | ConvertTo-Json -Depth 10
