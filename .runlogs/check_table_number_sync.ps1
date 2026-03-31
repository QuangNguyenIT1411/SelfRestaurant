$ErrorActionPreference='Stop'
$base='http://localhost:5100'
$s=New-Object Microsoft.PowerShell.Commands.WebRequestSession

$lp=Invoke-WebRequest "$base/Customer/Login?mode=login&force=true" -WebSession $s -UseBasicParsing
$tok=[regex]::Match($lp.Content,'name="__RequestVerificationToken"[^>]*value="([^"]+)"').Groups[1].Value
$lr=Invoke-WebRequest "$base/Customer/Login" -Method Post -WebSession $s -UseBasicParsing -Headers @{ 'X-Requested-With'='XMLHttpRequest'} -Body @{
  __RequestVerificationToken=$tok
  mode='login'
  'Login.Username'='lan.nguyen'
  'Login.Password'='123456'
  'Login.ReturnUrl'=''
}
$lj=$lr.Content|ConvertFrom-Json
if(-not $lj.success){ throw "Login failed: $($lr.Content)" }

# Reproduce old case: open menu without tableNumber param
$menuPage = Invoke-WebRequest "$base/Menu?tableId=2&BranchId=1" -WebSession $s -UseBasicParsing
$homePage = Invoke-WebRequest "$base/" -WebSession $s -UseBasicParsing

$menuTable = [regex]::Match($menuPage.Content,'<div class="display-5 fw-bold">\s*(\d+)\s*</div>')
$navTable = [regex]::Match($homePage.Content,'Bàn hiện tại \((\d+)\)')
$bannerTable = [regex]::Match($homePage.Content,'- Bàn\s+(\d+)\s*\|')

"MENU_TABLE=$($menuTable.Groups[1].Value)"
"NAV_TABLE=$($navTable.Groups[1].Value)"
"BANNER_TABLE=$($bannerTable.Groups[1].Value)"
