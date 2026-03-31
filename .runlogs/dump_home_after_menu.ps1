$ErrorActionPreference='Stop'
$base='http://localhost:5100'
$s=New-Object Microsoft.PowerShell.Commands.WebRequestSession
$lp=Invoke-WebRequest "$base/Customer/Login?mode=login&force=true" -WebSession $s -UseBasicParsing
$tok=[regex]::Match($lp.Content,'name="__RequestVerificationToken"[^>]*value="([^"]+)"').Groups[1].Value
$null=Invoke-WebRequest "$base/Customer/Login" -Method Post -WebSession $s -UseBasicParsing -Headers @{ 'X-Requested-With'='XMLHttpRequest'} -Body @{ __RequestVerificationToken=$tok; mode='login'; 'Login.Username'='lan.nguyen'; 'Login.Password'='123456'; 'Login.ReturnUrl'='' }
$null=Invoke-WebRequest "$base/Menu?tableId=2&BranchId=1" -WebSession $s -UseBasicParsing
$homePage=Invoke-WebRequest "$base/" -WebSession $s -UseBasicParsing
$homePage.Content | Out-File -FilePath "C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main\.runlogs\home_after_menu.html" -Encoding utf8
Write-Output "saved"
