$ErrorActionPreference='Stop'
$base='http://localhost:5100'
function Tok([string]$h){$ps=@('name="__RequestVerificationToken"[^>]*value="([^"]+)"',"name='__RequestVerificationToken'[^>]*value='([^']+)'",'value="([^"]+)"[^>]*name="__RequestVerificationToken"'); foreach($p in $ps){$m=[regex]::Match($h,$p,[System.Text.RegularExpressions.RegexOptions]::IgnoreCase); if($m.Success){return $m.Groups[1].Value}}; throw 'No token'}
$s=New-Object Microsoft.PowerShell.Commands.WebRequestSession
$lp=Invoke-WebRequest "$base/Staff/Account/Login" -WebSession $s -UseBasicParsing
$t=Tok $lp.Content
Invoke-WebRequest "$base/Staff/Account/Login" -Method Post -WebSession $s -UseBasicParsing -Headers @{ 'X-Requested-With'='XMLHttpRequest' } -Body @{ __RequestVerificationToken=$t; username='admin'; password='123456'; rememberMe='false' } | Out-Null
$cp=Invoke-WebRequest "$base/Admin/Customers/Create" -WebSession $s -UseBasicParsing
$ct=Tok $cp.Content
$u='dbg_cus_'+(Get-Date -Format 'yyyyMMddHHmmssfff')
$cr=Invoke-WebRequest "$base/Admin/Customers/Create" -Method Post -WebSession $s -UseBasicParsing -Body @{
  __RequestVerificationToken=$ct; Name='Dbg Customer'; Username=$u; Password='123456'; PhoneNumber='0901230000'; Email="$u@example.local"; Address='Dbg'; Gender='Khac'; DateOfBirth='2000-01-01'; LoyaltyPoints='0'; IsActive='true'
}
$cl=Invoke-WebRequest "$base/Admin/Customers?search=$u" -WebSession $s -UseBasicParsing
Set-Content -Path 'C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main\.runlogs\debug_new_customer_search.html' -Value $cl.Content -Encoding UTF8
Write-Output "username=$u"
Write-Output "create_uri=$($cr.BaseResponse.ResponseUri.AbsoluteUri)"
Write-Output "contains_username=$($cl.Content -match [regex]::Escape($u))"
Write-Output "has_edit_path=$($cl.Content -match '/Admin/Customers/Edit/')"
Write-Output "has_edit_query=$($cl.Content -match '/Admin/Customers/Edit\\?id=')"
Write-Output "first_3000="
$txt=$cl.Content
if($txt.Length -gt 3000){ $txt=$txt.Substring(0,3000)}
Write-Output $txt
