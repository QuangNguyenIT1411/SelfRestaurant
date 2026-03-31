$ErrorActionPreference='Stop'
function Add-Result($name, $ok, $detail) { $script:results += [pscustomobject]@{ Step=$name; Pass=[bool]$ok; Detail=$detail } }
function Tok([string]$h){
  $ps=@('name="__RequestVerificationToken"\s+type="hidden"\s+value="([^"]+)"','name="__RequestVerificationToken"\s+value="([^"]+)"','value="([^"]+)"\s+name="__RequestVerificationToken"')
  foreach($p in $ps){$m=[regex]::Match($h,$p); if($m.Success){ return $m.Groups[1].Value }}
  throw 'No token'
}
function Post-Form($url, $body, $session){
  Invoke-WebRequest $url -Method Post -WebSession $session -Body $body -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing
}

$results=@()
$root='http://localhost:5100'
$branchId=1
$cashierUser='cashier_lan'
$cashierPass='123456'
$staff=New-Object Microsoft.PowerShell.Commands.WebRequestSession

try {
  $loginPage=Invoke-WebRequest "$root/Staff/Account/Login" -WebSession $staff -UseBasicParsing
  $loginToken=Tok $loginPage.Content
  $loginResp=Post-Form "$root/Staff/Account/Login" @{username=$cashierUser;password=$cashierPass;__RequestVerificationToken=$loginToken} $staff
  Add-Result 'Cashier login' ($loginResp.StatusCode -in 200,302) "status=$($loginResp.StatusCode)"

  $indexPage=Invoke-WebRequest "$root/Staff/Cashier" -WebSession $staff -UseBasicParsing
  Add-Result 'Open Cashier index' ($indexPage.StatusCode -eq 200) "status=$($indexPage.StatusCode)"

  $historyPage=Invoke-WebRequest "$root/Staff/Cashier/History" -WebSession $staff -UseBasicParsing
  Add-Result 'Open Cashier history' ($historyPage.StatusCode -eq 200) "status=$($historyPage.StatusCode)"

  $reportPage=Invoke-WebRequest "$root/Staff/Cashier/Report" -WebSession $staff -UseBasicParsing
  Add-Result 'Open Cashier report' ($reportPage.StatusCode -eq 200) "status=$($reportPage.StatusCode)"

  $menuApi=Invoke-WebRequest "http://localhost:5101/api/branches/$branchId/menu" -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
  $dish=$null
  foreach($c in $menuApi.categories){ $dish=$c.dishes | Where-Object { $_.available -eq $true } | Select-Object -First 1; if($dish){break} }
  if($null -eq $dish){ throw 'No available dish for cashier test' }
  $dishId=[int]$dish.dishId

  $tables=Invoke-WebRequest "http://localhost:5101/api/branches/$branchId/tables" -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
  $table=$tables.tables | Where-Object { $_.isAvailable -eq $true } | Select-Object -First 1
  if($null -eq $table){ $table = $tables.tables | Select-Object -First 1 }
  $tableId=[int]$table.tableId

  Invoke-WebRequest "http://localhost:5102/api/tables/$tableId/occupy" -Method Post -ContentType 'application/json' -Body '{}' -UseBasicParsing | Out-Null
  Invoke-WebRequest "http://localhost:5102/api/tables/$tableId/order/items" -Method Post -ContentType 'application/json' -Body (@{dishId=$dishId;quantity=1;note='cashier-e2e'} | ConvertTo-Json) -UseBasicParsing | Out-Null
  Invoke-WebRequest "http://localhost:5102/api/tables/$tableId/order/submit" -Method Post -ContentType 'application/json' -Body '{}' -UseBasicParsing | Out-Null
  $activeOrder=Invoke-WebRequest "http://localhost:5102/api/tables/$tableId/order" -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
  $orderId=[int]$activeOrder.orderId
  Add-Result 'Create order for checkout' ($orderId -gt 0) "orderId=$orderId tableId=$tableId"

  $cashierOrders=Invoke-WebRequest "http://localhost:5105/api/branches/$branchId/cashier/orders" -UseBasicParsing | Select-Object -ExpandProperty Content
  Add-Result 'Order appears in cashier queue' ($cashierOrders -match ('\"orderId\":'+$orderId)) "orderId=$orderId"

  $indexPage2=Invoke-WebRequest "$root/Staff/Cashier" -WebSession $staff -UseBasicParsing
  $token2=Tok $indexPage2.Content
  $checkoutResp=Post-Form "$root/Staff/Cashier/Checkout" @{orderId=$orderId;discount=0;pointsUsed=0;paymentMethod='CASH';paymentAmount=999999;__RequestVerificationToken=$token2} $staff
  Add-Result 'Cashier checkout submit' ($checkoutResp.StatusCode -in 200,302) "status=$($checkoutResp.StatusCode)"

  Start-Sleep -Milliseconds 300

  $cashierOrdersAfter=Invoke-WebRequest "http://localhost:5105/api/branches/$branchId/cashier/orders" -UseBasicParsing | Select-Object -ExpandProperty Content
  Add-Result 'Order removed after checkout' (-not ($cashierOrdersAfter -match ('\"orderId\":'+$orderId))) "orderId=$orderId"

  $historyAfter=Invoke-WebRequest "$root/Staff/Cashier/History" -WebSession $staff -UseBasicParsing
  $hasBill = $historyAfter.Content -match 'BILL-'
  Add-Result 'Bill appears in history' $hasBill 'BILL marker found'

  $reportAfter=Invoke-WebRequest "$root/Staff/Cashier/Report" -WebSession $staff -UseBasicParsing
  $hasMetrics = ($reportAfter.Content -match 'BILL-' -or $reportAfter.Content -match 'table' -or $reportAfter.Content -match 'Total')
  Add-Result 'Report renders' $hasMetrics 'report html rendered'
}
catch {
  Add-Result 'ERROR' $false $_.Exception.Message
}

$results | Format-Table -AutoSize | Out-String | Write-Output
$pass=($results|Where-Object{$_.Pass -eq $true}).Count
$total=$results.Count
Write-Output "SUMMARY: $pass/$total PASS"
