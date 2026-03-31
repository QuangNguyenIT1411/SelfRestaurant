$ErrorActionPreference='Stop'
$base='http://localhost:5100'
$session=New-Object Microsoft.PowerShell.Commands.WebRequestSession
function Tok([string]$h){ $m=[regex]::Match($h,'name="__RequestVerificationToken"[^>]*value="([^"]+)"',[System.Text.RegularExpressions.RegexOptions]::IgnoreCase); if(!$m.Success){throw 'missing token'}; $m.Groups[1].Value }
$lp=Invoke-WebRequest "$base/Staff/Account/Login" -WebSession $session -UseBasicParsing
$t=Tok $lp.Content
$lr=Invoke-WebRequest "$base/Staff/Account/Login" -Method Post -WebSession $session -UseBasicParsing -Headers @{ 'X-Requested-With'='XMLHttpRequest' } -Body @{ __RequestVerificationToken=$t; username='admin'; password='123456'; rememberMe='false' }
$pages=@('/Admin/Employees','/Admin/Customers','/Admin/Dishes','/Admin/Ingredients','/Admin/Tables','/Admin/Categories')
foreach($p in $pages){
  $r=Invoke-WebRequest ($base+$p) -WebSession $session -UseBasicParsing
  $hasRaw = $r.Content -match 'asp-controller=|asp-action=|asp-area='
  Write-Output "$p RAW_ASP_ATTR=$hasRaw"
}
