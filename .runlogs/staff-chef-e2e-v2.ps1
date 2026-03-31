$ErrorActionPreference='Stop'
function Add-Result($name, $ok, $detail) {
  $script:results += [pscustomobject]@{ Step=$name; Pass=[bool]$ok; Detail=$detail }
}
function Tok([string]$h){
  $ps=@('name="__RequestVerificationToken"\s+type="hidden"\s+value="([^"]+)"','name="__RequestVerificationToken"\s+value="([^"]+)"','value="([^"]+)"\s+name="__RequestVerificationToken"')
  foreach($p in $ps){$m=[regex]::Match($h,$p); if($m.Success){ return $m.Groups[1].Value }}
  throw 'Khong tim thay token'
}
function Post-Form($url, $body, $session){
  return Invoke-WebRequest $url -Method Post -WebSession $session -Body $body -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing
}

$results=@()
$root='http://localhost:5100'
$branchId=1
$chefUser='chef_hung'
$chefPass='123456'
$staff=New-Object Microsoft.PowerShell.Commands.WebRequestSession

try {
  # 1) Login staff chef
  $loginPage=Invoke-WebRequest "$root/Staff/Account/Login" -WebSession $staff -UseBasicParsing
  $loginToken=Tok $loginPage.Content
  $loginBody=@{ username=$chefUser; password=$chefPass; __RequestVerificationToken=$loginToken }
  $loginResp=Post-Form "$root/Staff/Account/Login" $loginBody $staff
  Add-Result 'Chef login' ($loginResp.StatusCode -in 200,302) "status=$($loginResp.StatusCode)"

  $chefPage=Invoke-WebRequest "$root/Staff/Chef" -WebSession $staff -UseBasicParsing
  $hasChefDashboard=$chefPage.Content -match 'B?p - Dashboard'
  Add-Result 'Open Chef dashboard' $hasChefDashboard "status=$($chefPage.StatusCode)"

  # 2) Prepare one pending order for branch 1
  $menuApi=Invoke-WebRequest "http://localhost:5101/api/branches/$branchId/menu" -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
  $dish=$null
  foreach($c in $menuApi.categories){
    $dish=$c.dishes | Where-Object { $_.available -eq $true } | Select-Object -First 1
    if($dish){ break }
  }
  if($null -eq $dish){ throw 'Khong tim thay mon dang ban trong menu chi nhanh 1' }
  $dishId=[int]$dish.dishId

  $tables=Invoke-WebRequest "http://localhost:5101/api/branches/$branchId/tables" -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
  $table=$tables.tables | Where-Object { $_.isAvailable -eq $true } | Select-Object -First 1
  if($null -eq $table){ $table = $tables.tables | Select-Object -First 1 }
  $tableId=[int]$table.tableId

  Invoke-WebRequest "http://localhost:5102/api/tables/$tableId/occupy" -Method Post -ContentType 'application/json' -Body '{}' -UseBasicParsing | Out-Null
  Invoke-WebRequest "http://localhost:5102/api/tables/$tableId/order/items" -Method Post -ContentType 'application/json' -Body (@{dishId=$dishId;quantity=1;note='chef-e2e'} | ConvertTo-Json) -UseBasicParsing | Out-Null
  Invoke-WebRequest "http://localhost:5102/api/tables/$tableId/order/submit" -Method Post -ContentType 'application/json' -Body '{}' -UseBasicParsing | Out-Null
  $active=Invoke-WebRequest "http://localhost:5102/api/tables/$tableId/order" -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
  $orderId=[int]$active.orderId
  Add-Result 'Create pending order for chef' ($orderId -gt 0) "orderId=$orderId tableId=$tableId dishId=$dishId"

  # 3) Chef status transitions
  $chefToken=Tok $chefPage.Content
  Post-Form "$root/Staff/Chef/Start" @{orderId=$orderId;__RequestVerificationToken=$chefToken} $staff | Out-Null
  Start-Sleep -Milliseconds 200
  $prepList=Invoke-WebRequest "http://localhost:5102/api/branches/$branchId/chef/orders?status=PREPARING" -UseBasicParsing | Select-Object -ExpandProperty Content
  Add-Result 'Chef Start -> PREPARING' ($prepList -match ('\"orderId\":'+$orderId)) "orderId=$orderId"

  Post-Form "$root/Staff/Chef/Ready" @{orderId=$orderId;__RequestVerificationToken=$chefToken} $staff | Out-Null
  Start-Sleep -Milliseconds 200
  $readyList=Invoke-WebRequest "http://localhost:5102/api/branches/$branchId/chef/orders?status=READY" -UseBasicParsing | Select-Object -ExpandProperty Content
  Add-Result 'Chef Ready -> READY' ($readyList -match ('\"orderId\":'+$orderId)) "orderId=$orderId"

  Post-Form "$root/Staff/Chef/Serve" @{orderId=$orderId;__RequestVerificationToken=$chefToken} $staff | Out-Null
  Start-Sleep -Milliseconds 200
  $servingOrder=Invoke-WebRequest "http://localhost:5102/api/tables/$tableId/order" -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
  Add-Result 'Chef Serve -> SERVING' ($servingOrder.statusCode -eq 'SERVING') "status=$($servingOrder.statusCode)"

  # 4) Chef cancel flow on a new order
  $table2 = $tables.tables | Where-Object { [int]$_.tableId -ne $tableId } | Select-Object -First 1
  if($null -eq $table2){ $table2 = $table }
  $tableId2=[int]$table2.tableId
  Invoke-WebRequest "http://localhost:5102/api/tables/$tableId2/occupy" -Method Post -ContentType 'application/json' -Body '{}' -UseBasicParsing | Out-Null
  Invoke-WebRequest "http://localhost:5102/api/tables/$tableId2/order/items" -Method Post -ContentType 'application/json' -Body (@{dishId=$dishId;quantity=1;note='chef-cancel'} | ConvertTo-Json) -UseBasicParsing | Out-Null
  Invoke-WebRequest "http://localhost:5102/api/tables/$tableId2/order/submit" -Method Post -ContentType 'application/json' -Body '{}' -UseBasicParsing | Out-Null
  $active2=Invoke-WebRequest "http://localhost:5102/api/tables/$tableId2/order" -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
  $orderId2=[int]$active2.orderId
  Post-Form "$root/Staff/Chef/Cancel" @{orderId=$orderId2;reason='Het nguyen lieu';__RequestVerificationToken=$chefToken} $staff | Out-Null
  Start-Sleep -Milliseconds 200
  try {
    $check2=Invoke-WebRequest "http://localhost:5102/api/tables/$tableId2/order" -UseBasicParsing -ErrorAction Stop
    $cancelled = ($check2.Content | ConvertFrom-Json).statusCode -eq 'CANCELLED'
    Add-Result 'Chef Cancel order' $cancelled "orderId=$orderId2"
  } catch {
    Add-Result 'Chef Cancel order' $true "orderId=$orderId2 no active order"
  }

  # 5) Ingredient view + update
  $ingPage=Invoke-WebRequest "$root/Staff/Chef/Ingredients/$dishId" -WebSession $staff -UseBasicParsing
  $ingOk=($ingPage.StatusCode -eq 200) -and ($ingPage.Content -match 'Dish ID')
  Add-Result 'View dish ingredients (Chef)' $ingOk "dishId=$dishId"

  $lines=Invoke-WebRequest "http://localhost:5101/api/admin/dishes/$dishId/ingredients" -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
  $line=$lines | Where-Object { $_.isActive -eq $true } | Select-Object -First 1
  if($null -eq $line){ throw 'Khong co nguyen lieu active de test cap nhat' }
  $newQty=[decimal]1.23
  $ingToken=Tok $ingPage.Content
  Post-Form "$root/Staff/Chef/Ingredients/$dishId" @{ ingredientId=[int]$line.ingredientId; quantityPerDish=$newQty; __RequestVerificationToken=$ingToken } $staff | Out-Null
  Start-Sleep -Milliseconds 200
  $lines2=Invoke-WebRequest "http://localhost:5101/api/admin/dishes/$dishId/ingredients" -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
  $line2=$lines2 | Where-Object { [int]$_.ingredientId -eq [int]$line.ingredientId } | Select-Object -First 1
  $qtyMatched = [math]::Abs([decimal]$line2.quantityPerDish - $newQty) -lt [decimal]0.01
  Add-Result 'Update dish ingredients (Chef)' $qtyMatched "ingredientId=$($line.ingredientId) qty=$($line2.quantityPerDish)"

  # 6) Toggle dish availability (hide/turn off)
  $dishBefore=Invoke-WebRequest "http://localhost:5101/api/admin/dishes/$dishId" -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
  $target= -not [bool]$dishBefore.available
  Post-Form "$root/Staff/Chef/SetDishAvailability" @{ dishId=$dishId; available=$target; __RequestVerificationToken=$chefToken } $staff | Out-Null
  Start-Sleep -Milliseconds 200
  $dishAfter=Invoke-WebRequest "http://localhost:5101/api/admin/dishes/$dishId" -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
  Add-Result 'Toggle dish ON/OFF (Chef)' ([bool]$dishAfter.available -eq $target) "before=$($dishBefore.available) after=$($dishAfter.available)"

  # rollback availability to original
  Post-Form "$root/Staff/Chef/SetDishAvailability" @{ dishId=$dishId; available=$dishBefore.available; __RequestVerificationToken=$chefToken } $staff | Out-Null
}
catch {
  Add-Result 'ERROR' $false $_.Exception.Message
}

$results | Format-Table -AutoSize | Out-String | Write-Output
$pass=($results|Where-Object{$_.Pass -eq $true}).Count
$total=$results.Count
Write-Output "SUMMARY: $pass/$total PASS"


