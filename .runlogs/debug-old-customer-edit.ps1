$ErrorActionPreference='Stop'
$base='http://localhost:5088'
$oldPath='C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main_OLD\SelfRestaurant'
$iis='C:\Program Files\IIS Express\iisexpress.exe'

function Tok([string]$h){
  $ps=@('name="__RequestVerificationToken"[^>]*value="([^"]+)"',"name='__RequestVerificationToken'[^>]*value='([^']+)'",'value="([^"]+)"[^>]*name="__RequestVerificationToken"')
  foreach($p in $ps){$m=[regex]::Match($h,$p,[System.Text.RegularExpressions.RegexOptions]::IgnoreCase); if($m.Success){ return $m.Groups[1].Value }}
  throw 'no token'
}
function InputVal([string]$h,[string]$name){
  $esc=[regex]::Escape($name)
  $tag=[regex]::Match($h,'<input[^>]*name=[''\"]'+$esc+'[''\"][^>]*>',[System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  if(-not $tag.Success){ return '' }
  $vm=[regex]::Match($tag.Value,'value=[''\"]([^''\"]*)[''\"]',[System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  if($vm.Success){ return $vm.Groups[1].Value }
  return ''
}

Get-Process iisexpress -ErrorAction SilentlyContinue | Stop-Process -Force
$p=Start-Process -FilePath $iis -ArgumentList "/path:$oldPath", "/port:5088" -PassThru
Start-Sleep -Seconds 2

$s=New-Object Microsoft.PowerShell.Commands.WebRequestSession
$lp=Invoke-WebRequest "$base/Staff/Account/LogIn" -WebSession $s -UseBasicParsing
$t=Tok $lp.Content
$lr=Invoke-WebRequest "$base/Staff/Account/LogIn" -Method Post -WebSession $s -UseBasicParsing -Headers @{ 'X-Requested-With'='XMLHttpRequest' } -Body @{__RequestVerificationToken=$t;username='admin';password='123456';rememberMe='false'}
'loginRaw='+$lr.Content

# create temp customer
$cp=Invoke-WebRequest "$base/Admin/Customers/Create" -WebSession $s -UseBasicParsing
$ct=Tok $cp.Content
$u='dbg_old_cus_'+(Get-Date -Format 'yyyyMMddHHmmssfff')
$phone='09'+(Get-Random -Minimum 10000000 -Maximum 99999999)
$cr=Invoke-WebRequest "$base/Admin/Customers/Create" -Method Post -WebSession $s -UseBasicParsing -Body @{__RequestVerificationToken=$ct;Name='Dbg Old Cus';Username=$u;Password='123456';PhoneNumber=$phone;Email="$u@example.local";Address='dbg';Gender='Khac';DateOfBirth='2000-01-01';LoyaltyPoints='0';IsActive='true'}
'createUri='+$cr.BaseResponse.ResponseUri.AbsoluteUri

$sl=Invoke-WebRequest "$base/Admin/Customers?search=$u" -WebSession $s -UseBasicParsing
$idm=[regex]::Match($sl.Content,'/Admin/Customers/Edit/(\d+)')
if(-not $idm.Success){ throw 'cannot find edit id' }
$id=[int]$idm.Groups[1].Value
'customerId='+$id

$edit=Invoke-WebRequest "$base/Admin/Customers/Edit/$id" -WebSession $s -UseBasicParsing
$et=Tok $edit.Content
$oldPhone=InputVal $edit.Content 'PhoneNumber'
$newPhone='09'+(Get-Random -Minimum 10000000 -Maximum 99999999)
$body=@{__RequestVerificationToken=$et;CustomerID="$id";Name=(InputVal $edit.Content 'Name');Username=(InputVal $edit.Content 'Username');Password='';PhoneNumber=$newPhone;Email=(InputVal $edit.Content 'Email');Address=(InputVal $edit.Content 'Address');Gender=(InputVal $edit.Content 'Gender');DateOfBirth=(InputVal $edit.Content 'DateOfBirth');LoyaltyPoints=(InputVal $edit.Content 'LoyaltyPoints');IsActive='true'}

$pr=Invoke-WebRequest "$base/Admin/Customers/Edit/$id" -Method Post -WebSession $s -UseBasicParsing -Body $body
'postStatus='+$pr.StatusCode
'postUri='+$pr.BaseResponse.ResponseUri.AbsoluteUri
$psn=[string]$pr.Content
if($psn.Length -gt 1200){ $psn=$psn.Substring(0,1200) }
'postSnippet='+$psn

$ver=Invoke-WebRequest "$base/Admin/Customers/Edit/$id" -WebSession $s -UseBasicParsing
$verifyPhone=InputVal $ver.Content 'PhoneNumber'
'verifyPhone='+$verifyPhone
'expectedNewPhone='+$newPhone
'oldPhone='+$oldPhone
if($ver.Content -match 'alert alert-danger'){ 'hasValidationError=true' } else { 'hasValidationError=false' }

Stop-Process -Id $p.Id -Force
