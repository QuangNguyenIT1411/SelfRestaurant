$ErrorActionPreference='Stop'
function Add-Result($name, $ok, $detail) { $script:results += [pscustomobject]@{ ChucNang=$name; Pass=[bool]$ok; ChiTiet=$detail } }
function Tok([string]$h){
  $ps=@('name="__RequestVerificationToken"\s+type="hidden"\s+value="([^"]+)"','name="__RequestVerificationToken"\s+value="([^"]+)"','value="([^"]+)"\s+name="__RequestVerificationToken"')
  foreach($p in $ps){$m=[regex]::Match($h,$p); if($m.Success){ return $m.Groups[1].Value }}
  throw 'No token'
}
function Post-Form($url, $body, $session){ Invoke-WebRequest $url -Method Post -WebSession $session -Body $body -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing }

$results=@()
$root='http://localhost:5100'
$branchId=1
$managerUser='manager_q1'
$managerPass='123456'
$staff=New-Object Microsoft.PowerShell.Commands.WebRequestSession

try {
  # 1) login manager
  $loginPage=Invoke-WebRequest "$root/Staff/Account/Login" -WebSession $staff -UseBasicParsing
  $loginToken=Tok $loginPage.Content
  $loginResp=Post-Form "$root/Staff/Account/Login" @{username=$managerUser;password=$managerPass;__RequestVerificationToken=$loginToken} $staff
  Add-Result 'Đăng nhập Manager' ($loginResp.StatusCode -in 200,302) "status=$($loginResp.StatusCode)"

  # 2) open manager dashboard
  $managerPage=Invoke-WebRequest "$root/Staff/Manager" -WebSession $staff -UseBasicParsing
  Add-Result 'Mở dashboard Manager' ($managerPage.StatusCode -eq 200) "status=$($managerPage.StatusCode)"

  # 3) KPI match APIs
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
  Add-Result 'KPI Manager khớp dữ liệu API' $kpiOk "pending=$pending preparing=$preparing ready=$ready cashier=$activeCashier bills=$billCount"

  # 4) Top dishes section
  $topDishIds=Invoke-WebRequest "http://localhost:5102/api/branches/$branchId/top-dishes?count=5" -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
  if(@($topDishIds).Count -gt 0){
    $first=[int]$topDishIds[0]
    $hasTop = $html -match ('#'+$first)
    Add-Result 'Hiển thị món bán chạy' $hasTop "firstDishId=$first"
  } else {
    Add-Result 'Hiển thị món bán chạy' $true 'no top dish data'
  }

  # 5) Navigate to Chef via manager
  $chefPage=Invoke-WebRequest "$root/Staff/Chef" -WebSession $staff -UseBasicParsing
  $chefOk = ($chefPage.StatusCode -eq 200) -and ($chefPage.Content -match 'Bếp')
  Add-Result 'Điều phối Bếp từ Manager' $chefOk "status=$($chefPage.StatusCode)"

  # 6) Navigate to Cashier via manager
  $cashierPage=Invoke-WebRequest "$root/Staff/Cashier" -WebSession $staff -UseBasicParsing
  $cashierOk = ($cashierPage.StatusCode -eq 200) -and ($cashierPage.Content -match 'Thu ngân')
  Add-Result 'Điều phối Thu ngân từ Manager' $cashierOk "status=$($cashierPage.StatusCode)"

  # 7) access Admin dashboard link (manager allowed)
  $adminDash=Invoke-WebRequest "$root/Admin/Dashboard" -WebSession $staff -UseBasicParsing
  Add-Result 'Truy cập Admin Dashboard từ Manager' ($adminDash.StatusCode -eq 200) "status=$($adminDash.StatusCode)"

  # 8) access Admin Categories link
  $adminCategories=Invoke-WebRequest "$root/Admin/Categories" -WebSession $staff -UseBasicParsing
  Add-Result 'Truy cập Danh mục món (Admin/Categories)' ($adminCategories.StatusCode -eq 200) "status=$($adminCategories.StatusCode)"

  # 9) logout manager
  $logoutToken=Tok $managerPage.Content
  Post-Form "$root/Staff/Account/Logout" @{__RequestVerificationToken=$logoutToken} $staff | Out-Null
  $afterLogout=Invoke-WebRequest "$root/Staff/Manager" -WebSession $staff -UseBasicParsing
  $loggedOut = $afterLogout.BaseResponse.ResponseUri.AbsoluteUri -like '*Staff/Account/Login*'
  Add-Result 'Đăng xuất Manager' $loggedOut "redirect=$($afterLogout.BaseResponse.ResponseUri.AbsoluteUri)"

  # 10) unauthorized check after logout
  $chefAfterLogout=Invoke-WebRequest "$root/Staff/Chef" -WebSession $staff -UseBasicParsing
  $blocked = $chefAfterLogout.BaseResponse.ResponseUri.AbsoluteUri -like '*Staff/Account/Login*'
  Add-Result 'Chặn truy cập Staff sau logout' $blocked "redirect=$($chefAfterLogout.BaseResponse.ResponseUri.AbsoluteUri)"
}
catch {
  Add-Result 'ERROR' $false $_.Exception.Message
}

$results | Format-Table -AutoSize | Out-String | Write-Output
$pass=($results|Where-Object{$_.Pass -eq $true}).Count
$total=$results.Count
Write-Output "SUMMARY: $pass/$total PASS"
