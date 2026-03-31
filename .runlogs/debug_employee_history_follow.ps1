$ErrorActionPreference='Stop'
$base='http://localhost:5100'
$session=New-Object Microsoft.PowerShell.Commands.WebRequestSession
function Tok([string]$h){([regex]::Match($h,'name="__RequestVerificationToken"[^>]*value="([^"]+)"')).Groups[1].Value}
$lp=Invoke-WebRequest "$base/Staff/Account/Login" -WebSession $session -UseBasicParsing
$t=Tok $lp.Content
$lr=Invoke-WebRequest "$base/Staff/Account/Login" -Method Post -WebSession $session -UseBasicParsing -Headers @{ 'X-Requested-With'='XMLHttpRequest' } -Body @{ __RequestVerificationToken=$t; username='admin'; password='123456'; rememberMe='false' }
$idx=Invoke-WebRequest "$base/Admin/Employees" -WebSession $session -UseBasicParsing
$m=[regex]::Match($idx.Content,'/Admin/Employees/History/(\d+)')
$id=[int]$m.Groups[1].Value
Write-Output "ID=$id"
$hist=Invoke-WebRequest "$base/Admin/Employees/History/$id" -WebSession $session -UseBasicParsing
Write-Output "FINAL_STATUS=$($hist.StatusCode)"
Write-Output "FINAL_URI=$($hist.BaseResponse.ResponseUri.AbsoluteUri)"
