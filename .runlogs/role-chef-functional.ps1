$ErrorActionPreference='Stop'
function Add-Result($name, $ok, $detail) { $script:results += [pscustomobject]@{ ChucNang=$name; Pass=[bool]$ok; ChiTiet=$detail } }
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
$chefUser='chef_hung'
$chefPass='123456'
$staff=New-Object Microsoft.PowerShell.Commands.WebRequestSession

try {
  # 0) Dang nhap Chef
  $loginPage=Invoke-WebRequest "$root/Staff/Account/Login" -WebSession $staff -UseBasicParsing
  $loginToken=Tok $loginPage.Content
  $loginResp=Post-Form "$root/Staff/Account/Login" @{username=$chefUser;password=$chefPass;__RequestVerificationToken=$loginToken} $staff
  Add-Result 'Đăng nhập Chef' ($loginResp.StatusCode -in 200,302) "status=$($loginResp.StatusCode)"

  # 1) Mo dashboard Chef
  $chefPage=Invoke-WebRequest "$root/Staff/Chef" -WebSession $staff -UseBasicParsing
  Add-Result 'Mở dashboard Chef' ($chefPage.StatusCode -eq 200) "status=$($chefPage.StatusCode)"

  # Tao du lieu don hang test
  $menuApi=Invoke-WebRequest "http://localhost:5101/api/branches/$branchId/menu" -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
  $dish=$null
  foreach($c in $menuApi.categories){ $dish=$c.dishes | Where-Object { $_.available -eq $true } | Select-Object -First 1; if($dish){break} }
  if($null -eq $dish){ throw 'Khong tim thay mon dang ban trong menu' }
  $dishId=[int]$dish.dishId

  $tables=Invoke-WebRequest "http://localhost:5101/api/branches/$branchId/tables" -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
  $table=$tables.tables | Where-Object { $_.isAvailable -eq $true } | Select-Object -First 1
  if($null -eq $table){ $table = $tables.tables | Select-Object -First 1 }
  $tableId=[int]$table.tableId

  Invoke-WebRequest "http://localhost:5102/api/tables/$tableId/occupy" -Method Post -ContentType 'application/json' -Body '{}' -UseBasicParsing | Out-Null
  Invoke-WebRequest "http://localhost:5102/api/tables/$tableId/order/items" -Method Post -ContentType 'application/json' -Body (@{dishId=$dishId;quantity=1;note='role-chef'} | ConvertTo-Json) -UseBasicParsing | Out-Null
  Invoke-WebRequest "http://localhost:5102/api/tables/$tableId/order/submit" -Method Post -ContentType 'application/json' -Body '{}' -UseBasicParsing | Out-Null
  $active=Invoke-WebRequest "http://localhost:5102/api/tables/$tableId/order" -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
  $orderId=[int]$active.orderId
  Add-Result 'Tạo đơn test cho Chef' ($orderId -gt 0) "orderId=$orderId tableId=$tableId dishId=$dishId"

  $chefToken=Tok $chefPage.Content

  # 2) Bat dau che bien
  Post-Form "$root/Staff/Chef/Start" @{orderId=$orderId;__RequestVerificationToken=$chefToken} $staff | Out-Null
  Start-Sleep -Milliseconds 200
  $prepList=Invoke-WebRequest "http://localhost:5102/api/branches/$branchId/chef/orders?status=PREPARING" -UseBasicParsing | Select-Object -ExpandProperty Content
  Add-Result 'Bắt đầu chế biến (Start)' ($prepList -match ('\"orderId\":'+$orderId)) "orderId=$orderId"

  # 3) Danh dau san sang
  Post-Form "$root/Staff/Chef/Ready" @{orderId=$orderId;__RequestVerificationToken=$chefToken} $staff | Out-Null
  Start-Sleep -Milliseconds 200
  $readyList=Invoke-WebRequest "http://localhost:5102/api/branches/$branchId/chef/orders?status=READY" -UseBasicParsing | Select-Object -ExpandProperty Content
  Add-Result 'Đánh dấu sẵn sàng (Ready)' ($readyList -match ('\"orderId\":'+$orderId)) "orderId=$orderId"

  # 4) Chuyen phuc vu
  Post-Form "$root/Staff/Chef/Serve" @{orderId=$orderId;__RequestVerificationToken=$chefToken} $staff | Out-Null
  Start-Sleep -Milliseconds 200
  $servingOrder=Invoke-WebRequest "http://localhost:5102/api/tables/$tableId/order" -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
  Add-Result 'Chuyển phục vụ (Serve)' ($servingOrder.statusCode -eq 'SERVING') "status=$($servingOrder.statusCode)"

  # 5) Huy don
  $table2 = $tables.tables | Where-Object { [int]$_.tableId -ne $tableId } | Select-Object -First 1
  if($null -eq $table2){ $table2 = $table }
  $tableId2=[int]$table2.tableId
  Invoke-WebRequest "http://localhost:5102/api/tables/$tableId2/occupy" -Method Post -ContentType 'application/json' -Body '{}' -UseBasicParsing | Out-Null
  Invoke-WebRequest "http://localhost:5102/api/tables/$tableId2/order/items" -Method Post -ContentType 'application/json' -Body (@{dishId=$dishId;quantity=1;note='cancel-chef'} | ConvertTo-Json) -UseBasicParsing | Out-Null
  Invoke-WebRequest "http://localhost:5102/api/tables/$tableId2/order/submit" -Method Post -ContentType 'application/json' -Body '{}' -UseBasicParsing | Out-Null
  $active2=Invoke-WebRequest "http://localhost:5102/api/tables/$tableId2/order" -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
  $orderId2=[int]$active2.orderId
  Post-Form "$root/Staff/Chef/Cancel" @{orderId=$orderId2;reason='Het nguyen lieu';__RequestVerificationToken=$chefToken} $staff | Out-Null
  Start-Sleep -Milliseconds 200
  try {
    $check2=Invoke-WebRequest "http://localhost:5102/api/tables/$tableId2/order" -UseBasicParsing -ErrorAction Stop
    $cancelled = (($check2.Content | ConvertFrom-Json).statusCode -eq 'CANCELLED')
    Add-Result 'Hủy đơn (Cancel)' $cancelled "orderId=$orderId2"
  } catch {
    Add-Result 'Hủy đơn (Cancel)' $true "orderId=$orderId2 no active order"
  }

  # 6) Xem nguyen lieu mon
  $ingPage=Invoke-WebRequest "$root/Staff/Chef/Ingredients/$dishId" -WebSession $staff -UseBasicParsing
  $ingOk=($ingPage.StatusCode -eq 200) -and ($ingPage.Content -match 'Dish ID')
  Add-Result 'Xem nguyên liệu món' $ingOk "dishId=$dishId"

  # 7) Sua nguyen lieu mon
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
  Add-Result 'Sửa nguyên liệu theo món' $qtyMatched "ingredientId=$($line.ingredientId) qty=$($line2.quantityPerDish)"

  # 8) Tat/Bat mon khi het nguyen lieu
  $dishBefore=Invoke-WebRequest "http://localhost:5101/api/admin/dishes/$dishId" -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
  $target= -not [bool]$dishBefore.available
  Post-Form "$root/Staff/Chef/SetDishAvailability" @{ dishId=$dishId; available=$target; __RequestVerificationToken=$chefToken } $staff | Out-Null
  Start-Sleep -Milliseconds 200
  $dishAfter=Invoke-WebRequest "http://localhost:5101/api/admin/dishes/$dishId" -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
  Add-Result 'Ẩn/Tắt món khi hết NL' ([bool]$dishAfter.available -eq $target) "before=$($dishBefore.available) after=$($dishAfter.available)"

  # rollback
  Post-Form "$root/Staff/Chef/SetDishAvailability" @{ dishId=$dishId; available=$dishBefore.available; __RequestVerificationToken=$chefToken } $staff | Out-Null
}
catch {
  Add-Result 'ERROR' $false $_.Exception.Message
}

$results | Format-Table -AutoSize | Out-String | Write-Output
$pass=($results|Where-Object{$_.Pass -eq $true}).Count
$total=$results.Count
Write-Output "SUMMARY: $pass/$total PASS"
