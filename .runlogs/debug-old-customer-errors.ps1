$ErrorActionPreference='Stop'
$base='http://localhost:5088'
$oldPath='C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main_OLD\SelfRestaurant'
$iis='C:\Program Files\IIS Express\iisexpress.exe'
function Tok([string]$h){$ps=@('name="__RequestVerificationToken"[^>]*value="([^"]+)"',"name='__RequestVerificationToken'[^>]*value='([^']+)'",'value="([^"]+)"[^>]*name="__RequestVerificationToken"'); foreach($p in $ps){$m=[regex]::Match($h,$p,[System.Text.RegularExpressions.RegexOptions]::IgnoreCase); if($m.Success){return $m.Groups[1].Value}}; throw 'no token'}
function InputVal([string]$h,[string]$n){$esc=[regex]::Escape($n);$tag=[regex]::Match($h,'<input[^>]*name=[''\"]'+$esc+'[''\"][^>]*>',[System.Text.RegularExpressions.RegexOptions]::IgnoreCase); if(!$tag.Success){return ''};$vm=[regex]::Match($tag.Value,'value=[''\"]([^''\"]*)[''\"]',[System.Text.RegularExpressions.RegexOptions]::IgnoreCase); if($vm.Success){return $vm.Groups[1].Value};''}
Get-Process iisexpress -ErrorAction SilentlyContinue | Stop-Process -Force
$p=Start-Process -FilePath $iis -ArgumentList "/path:$oldPath", "/port:5088" -PassThru
Start-Sleep -Seconds 2
$s=New-Object Microsoft.PowerShell.Commands.WebRequestSession
$lp=Invoke-WebRequest "$base/Staff/Account/LogIn" -WebSession $s -UseBasicParsing
$t=Tok $lp.Content
Invoke-WebRequest "$base/Staff/Account/LogIn" -Method Post -WebSession $s -UseBasicParsing -Headers @{ 'X-Requested-With'='XMLHttpRequest' } -Body @{__RequestVerificationToken=$t;username='admin';password='123456';rememberMe='false'} | Out-Null
$cp=Invoke-WebRequest "$base/Admin/Customers/Create" -WebSession $s -UseBasicParsing
$ct=Tok $cp.Content
$u='dbg_old_cus_'+(Get-Date -Format 'yyyyMMddHHmmssfff')
$cr=Invoke-WebRequest "$base/Admin/Customers/Create" -Method Post -WebSession $s -UseBasicParsing -Body @{__RequestVerificationToken=$ct;Name='Dbg Old Cus';Username=$u;Password='123456';PhoneNumber='0901234567';Email="$u@example.local";Address='dbg';Gender='Khac';DateOfBirth='2000-01-01';LoyaltyPoints='0';IsActive='true'}
$sl=Invoke-WebRequest "$base/Admin/Customers?search=$u" -WebSession $s -UseBasicParsing
$id=[int]([regex]::Match($sl.Content,'/Admin/Customers/Edit/(\d+)').Groups[1].Value)
$edit=Invoke-WebRequest "$base/Admin/Customers/Edit/$id" -WebSession $s -UseBasicParsing
$et=Tok $edit.Content
$newPhone='09'+(Get-Random -Minimum 10000000 -Maximum 99999999)
$body=@{__RequestVerificationToken=$et;CustomerID="$id";Name=(InputVal $edit.Content 'Name');Username=(InputVal $edit.Content 'Username');Password='';PhoneNumber=$newPhone;Email=(InputVal $edit.Content 'Email');Address=(InputVal $edit.Content 'Address');Gender=(InputVal $edit.Content 'Gender');DateOfBirth=(InputVal $edit.Content 'DateOfBirth');LoyaltyPoints=(InputVal $edit.Content 'LoyaltyPoints');IsActive='true'}
$pr=Invoke-WebRequest "$base/Admin/Customers/Edit/$id" -Method Post -WebSession $s -UseBasicParsing -Body $body
$html=[string]$pr.Content
Set-Content -Path 'C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main\.runlogs\debug_old_customer_post.html' -Value $html -Encoding UTF8
"postUri="+$pr.BaseResponse.ResponseUri.AbsoluteUri
$errs=[regex]::Matches($html,'<li>(.*?)</li>',[System.Text.RegularExpressions.RegexOptions]::Singleline)
foreach($e in $errs){ $txt=($e.Groups[1].Value -replace '<[^>]+>',' ').Trim(); if($txt){ "err="+$txt } }
$spanErr=[regex]::Matches($html,'<span[^>]*class="[^"]*text-danger[^"]*"[^>]*>(.*?)</span>',[System.Text.RegularExpressions.RegexOptions]::Singleline)
foreach($e in $spanErr){ $txt=($e.Groups[1].Value -replace '<[^>]+>',' ').Trim(); if($txt){ "spanErr="+$txt } }
Stop-Process -Id $p.Id -Force
