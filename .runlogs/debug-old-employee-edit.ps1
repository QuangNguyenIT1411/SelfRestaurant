$ErrorActionPreference='Stop'
$base='http://localhost:5088'
$oldPath='C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main_OLD\SelfRestaurant'
$iis='C:\Program Files\IIS Express\iisexpress.exe'
function Tok([string]$h){$ps=@('name="__RequestVerificationToken"[^>]*value="([^"]+)"',"name='__RequestVerificationToken'[^>]*value='([^']+)'",'value="([^"]+)"[^>]*name="__RequestVerificationToken"'); foreach($p in $ps){$m=[regex]::Match($h,$p,[System.Text.RegularExpressions.RegexOptions]::IgnoreCase);if($m.Success){return $m.Groups[1].Value}};throw 'no token'}
Get-Process iisexpress -ErrorAction SilentlyContinue | Stop-Process -Force
$p=Start-Process -FilePath $iis -ArgumentList "/path:$oldPath", "/port:5088" -PassThru
Start-Sleep -Seconds 2
$s=New-Object Microsoft.PowerShell.Commands.WebRequestSession
$lp=Invoke-WebRequest "$base/Staff/Account/LogIn" -WebSession $s -UseBasicParsing
$t=Tok $lp.Content
$lr=Invoke-WebRequest "$base/Staff/Account/LogIn" -Method Post -WebSession $s -UseBasicParsing -Headers @{ 'X-Requested-With'='XMLHttpRequest' } -Body @{__RequestVerificationToken=$t;username='admin';password='123456';rememberMe='false'}
"login_raw=" + $lr.Content
$edit=Invoke-WebRequest "$base/Admin/Employees/Edit/10" -WebSession $s -UseBasicParsing
$et=Tok $edit.Content
function V($h,$n){$m=[regex]::Match($h,"<input[^>]*name=['\"]$n['\"][^>]*value=['\"]([^'\"]*)['\"]",[System.Text.RegularExpressions.RegexOptions]::IgnoreCase); if($m.Success){return $m.Groups[1].Value}; ''}
function Sel($h,$n){$m=[regex]::Match($h,"<select[^>]*name=['\"]$n['\"][^>]*>(.*?)</select>",[System.Text.RegularExpressions.RegexOptions]::Singleline); if(!$m.Success){return '1'}; $s=$m.Groups[1].Value; $sm=[regex]::Match($s,'<option[^>]*selected[^>]*value="(\d+)"',[System.Text.RegularExpressions.RegexOptions]::IgnoreCase); if($sm.Success){return $sm.Groups[1].Value}; $f=[regex]::Match($s,'value="(\d+)"'); if($f.Success){return $f.Groups[1].Value}; '1'}
$html=$edit.Content
$phone='09'+(Get-Random -Minimum 10000000 -Maximum 99999999)
$body=@{__RequestVerificationToken=$et;EmployeeID='10';Name=(V $html 'Name');Username=(V $html 'Username');Password='';Phone=$phone;Email=(V $html 'Email');Salary=(V $html 'Salary');Shift=(V $html 'Shift');BranchID=(Sel $html 'BranchID');RoleID=(Sel $html 'RoleID');IsActive='true'}
try{
 $pr=Invoke-WebRequest "$base/Admin/Employees/Edit/10" -Method Post -WebSession $s -UseBasicParsing -Body $body
 "post_status="+$pr.StatusCode
 "post_uri="+$pr.BaseResponse.ResponseUri.AbsoluteUri
 $txt=[string]$pr.Content; if($txt.Length -gt 1200){$txt=$txt.Substring(0,1200)}
 "post_snippet="+$txt
}catch{
 if($_.Exception.Response){
  $resp=$_.Exception.Response
  "post_error_status="+[int]$resp.StatusCode
  $sr=New-Object IO.StreamReader($resp.GetResponseStream())
  $content=$sr.ReadToEnd(); if($content.Length -gt 1500){$content=$content.Substring(0,1500)}
  "post_error_snippet="+$content
 } else { "post_error="+$_.Exception.Message }
}
$ver=Invoke-WebRequest "$base/Admin/Employees/Edit/10" -WebSession $s -UseBasicParsing
"verify_phone=" + (V $ver.Content 'Phone')
Stop-Process -Id $p.Id -Force
