$ErrorActionPreference='Stop'
function Add-Result($name, $ok, $detail) { $script:results += [pscustomobject]@{ Step=$name; Pass=[bool]$ok; Detail=$detail } }
function Tok([string]$h){
  $ps=@('name="__RequestVerificationToken"\s+type="hidden"\s+value="([^"]+)"','name="__RequestVerificationToken"\s+value="([^"]+)"','value="([^"]+)"\s+name="__RequestVerificationToken"')
  foreach($p in $ps){$m=[regex]::Match($h,$p); if($m.Success){ return $m.Groups[1].Value }}
  throw 'Khong tim thay token'
}
function Post-Form($url, $body, $session){
  Invoke-WebRequest $url -Method Post -WebSession $session -Body $body -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing
}

$results=@()
$root='http://localhost:5100'
$branchId=1
$managerUser='manager_q1'
$managerPass='123456'
$staff=New-Object Microsoft.PowerShell.Commands.WebRequestSession

try {
  # Login manager
  $loginPage=Invoke-WebRequest "$root/Staff/Account/Login" -WebSession $staff -UseBasicParsing
  $loginToken=Tok $loginPage.Content
  $loginResp=Post-Form "$root/Staff/Account/Login" @{username=$managerUser;password=$managerPass;__RequestVerificationToken=$loginToken} $staff
  Add-Result 'Manager login' ($loginResp.StatusCode -in 200,302) "status=$($loginResp.StatusCode)"

  $managerPage=Invoke-WebRequest "$root/Staff/Manager" -WebSession $staff -UseBasicParsing
  Add-Result 'Open Manager dashboard' ($managerPage.StatusCode -eq 200) "status=$($managerPage.StatusCode)"

  # Manager can open Chef/Cashier pages
  $chefPage=Invoke-WebRequest "$root/Staff/Chef" -WebSession $staff -UseBasicParsing
  Add-Result 'Manager access Chef page' ($chefPage.StatusCode -eq 200) "status=$($chefPage.StatusCode)"

  $cashierPage=Invoke-WebRequest "$root/Staff/Cashier" -WebSession $staff -UseBasicParsing
  Add-Result 'Manager access Cashier page' ($cashierPage.StatusCode -eq 200) "status=$($cashierPage.StatusCode)"

  # Validate manager KPIs against APIs (presence check by number on page)
  $chefOrders=Invoke-WebRequest "http://localhost:5102/api/branches/$branchId/chef/orders" -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
  $cashierOrders=Invoke-WebRequest "http://localhost:5105/api/branches/$branchId/cashier/orders" -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
  $branchReport=Invoke-WebRequest "http://localhost:5105/api/branches/$branchId/cashier/report" -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json

  $pending = @($chefOrders | Where-Object { $_.statusCode -in @('PENDING','CONFIRMED') }).Count
  $preparing = @($chefOrders | Where-Object { $_.statusCode -eq 'PREPARING' }).Count
  $ready = @($chefOrders | Where-Object { $_.statusCode -in @('READY','SERVING') }).Count
  $activeCashier = @($cashierOrders).Count
  $billCount = [int]$branchReport.billCount

  $html=$managerPage.Content
  $kpiOk = ($html -match (">\s*$pending\s*<")) -and ($html -match (">\s*$preparing\s*<")) -and ($html -match (">\s*$ready\s*<")) -and ($html -match (">\s*$activeCashier\s*<")) -and ($html -match (">\s*$billCount\s*<"))
  Add-Result 'Manager KPI matches API values' $kpiOk "pending=$pending preparing=$preparing ready=$ready cashier=$activeCashier bills=$billCount"

  # Top dishes block rendered
  $topDishIds=Invoke-WebRequest "http://localhost:5102/api/branches/$branchId/top-dishes?count=5" -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
  if(@($topDishIds).Count -gt 0){
    $first=[int]$topDishIds[0]
    $hasTop = $html -match ('#'+$first)
    Add-Result 'Manager top dishes rendered' $hasTop "firstDishId=$first"
  } else {
    Add-Result 'Manager top dishes rendered' $true 'no top dish data to validate'
  }
}
catch {
  Add-Result 'ERROR' $false $_.Exception.Message
}

$results | Format-Table -AutoSize | Out-String | Write-Output
$pass=($results|Where-Object{$_.Pass -eq $true}).Count
$total=$results.Count
Write-Output "SUMMARY: $pass/$total PASS"
