$ErrorActionPreference='Stop'
$base='http://localhost:5100'

function Tok([string]$h){
  $ps=@('name="__RequestVerificationToken"[^>]*value="([^"]+)"',"name='__RequestVerificationToken'[^>]*value='([^']+)'",'value="([^"]+)"[^>]*name="__RequestVerificationToken"')
  foreach($p in $ps){$m=[regex]::Match($h,$p,[System.Text.RegularExpressions.RegexOptions]::IgnoreCase);if($m.Success){return $m.Groups[1].Value}}
  throw 'No token'
}
function IdFromEdit($html,$ctrl){
  $m=[regex]::Matches($html,"/Admin/$ctrl/Edit/(\\d+)",[System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  if($m.Count -gt 0){ return [int]$m[0].Groups[1].Value }
  return 0
}

$s=New-Object Microsoft.PowerShell.Commands.WebRequestSession
$lp=Invoke-WebRequest "$base/Staff/Account/Login" -WebSession $s -UseBasicParsing
$t=Tok $lp.Content
$lr=Invoke-WebRequest "$base/Staff/Account/Login" -Method Post -WebSession $s -UseBasicParsing -Headers @{ 'X-Requested-With'='XMLHttpRequest' } -Body @{ __RequestVerificationToken=$t; username='admin'; password='123456'; rememberMe='false' }
'login_raw=' + ($lr.Content | Out-String)

# customer create
$cp=Invoke-WebRequest "$base/Admin/Customers/Create" -WebSession $s -UseBasicParsing
$ct=Tok $cp.Content
$u='dbg_cus_'+(Get-Date -Format 'yyyyMMddHHmmssfff')
$cr=Invoke-WebRequest "$base/Admin/Customers/Create" -Method Post -WebSession $s -UseBasicParsing -Body @{
  __RequestVerificationToken=$ct
  Name='Dbg Customer'
  Username=$u
  Password='123456'
  PhoneNumber='0901230000'
  Email="$u@example.local"
  Address='Dbg'
  Gender='Khac'
  DateOfBirth='2000-01-01'
  LoyaltyPoints='0'
  IsActive='true'
}
'customer_create_uri=' + $cr.BaseResponse.ResponseUri.AbsoluteUri
$cl=Invoke-WebRequest "$base/Admin/Customers?search=$u" -WebSession $s -UseBasicParsing
'customer_edit_id=' + (IdFromEdit $cl.Content 'Customers')
if($cl.Content -match 'alert alert-danger'){ 'customer_list_has_error=true' } else { 'customer_list_has_error=false' }

# employee create
$ep=Invoke-WebRequest "$base/Admin/Employees/Create" -WebSession $s -UseBasicParsing
$et=Tok $ep.Content
$branch=[regex]::Match($ep.Content,'<select[^>]*name="BranchId"[^>]*>(.*?)</select>',[System.Text.RegularExpressions.RegexOptions]::Singleline).Groups[1].Value
$role=[regex]::Match($ep.Content,'<select[^>]*name="RoleId"[^>]*>(.*?)</select>',[System.Text.RegularExpressions.RegexOptions]::Singleline).Groups[1].Value
$bid=[regex]::Match($branch,'value="(\\d+)"').Groups[1].Value
$rid=[regex]::Match($role,'value="(\\d+)"').Groups[1].Value
$eu='dbg_emp_'+(Get-Date -Format 'yyyyMMddHHmmssfff')
$er=Invoke-WebRequest "$base/Admin/Employees/Create" -Method Post -WebSession $s -UseBasicParsing -Body @{
  __RequestVerificationToken=$et
  Name='Dbg Employee'
  Username=$eu
  Password='123456'
  Phone='0908880000'
  Email="$eu@example.local"
  Shift='Sang'
  Salary='9000000'
  BranchId=$bid
  RoleId=$rid
  IsActive='true'
}
'employee_create_uri=' + $er.BaseResponse.ResponseUri.AbsoluteUri
$el=Invoke-WebRequest "$base/Admin/Employees?search=$eu" -WebSession $s -UseBasicParsing
'employee_edit_id=' + (IdFromEdit $el.Content 'Employees')
if($el.Content -match 'alert alert-danger'){ 'employee_list_has_error=true' } else { 'employee_list_has_error=false' }

# dish create
$dp=Invoke-WebRequest "$base/Admin/Dishes/Create" -WebSession $s -UseBasicParsing
$dt=Tok $dp.Content
$category=[regex]::Match($dp.Content,'<select[^>]*name="CategoryId"[^>]*>(.*?)</select>',[System.Text.RegularExpressions.RegexOptions]::Singleline).Groups[1].Value
$cid=[regex]::Match($category,'value="(\\d+)"').Groups[1].Value
$dn='DBG_DISH_'+(Get-Date -Format 'yyyyMMddHHmmssfff')
$dr=Invoke-WebRequest "$base/Admin/Dishes/Create" -Method Post -WebSession $s -UseBasicParsing -Body @{
  __RequestVerificationToken=$dt
  Name=$dn
  Price='123000'
  Unit='Phan'
  CategoryId=$cid
  Description='Dbg dish'
  Image='/images/placeholder.jpg'
  Available='true'
  IsActive='true'
}
'dish_create_uri=' + $dr.BaseResponse.ResponseUri.AbsoluteUri
$dl=Invoke-WebRequest "$base/Admin/Dishes?search=$dn" -WebSession $s -UseBasicParsing
'dish_edit_id=' + (IdFromEdit $dl.Content 'Dishes')
if($dl.Content -match 'alert alert-danger'){ 'dish_list_has_error=true' } else { 'dish_list_has_error=false' }

