$ErrorActionPreference = 'Stop'
$base='http://localhost:5100'
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
function Get-Token([string]$html){([regex]::Match($html, 'name="__RequestVerificationToken"[^>]*value="([^"]+)"')).Groups[1].Value}

# login
$lp = Invoke-WebRequest "$base/Staff/Account/Login" -WebSession $session -UseBasicParsing
$t = Get-Token $lp.Content
$lr = Invoke-WebRequest "$base/Staff/Account/Login" -Method Post -WebSession $session -UseBasicParsing -Headers @{ 'X-Requested-With'='XMLHttpRequest' } -Body @{ __RequestVerificationToken=$t; username='admin'; password='123456'; rememberMe='false' }

# pick first employee id from index
$idx = Invoke-WebRequest "$base/Admin/Employees" -WebSession $session -UseBasicParsing
$m = [regex]::Match($idx.Content, '/Admin/Employees/History/(\d+)', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
if(-not $m.Success){ throw 'No history link found' }
$id = [int]$m.Groups[1].Value
Write-Output "EMP_ID=$id"

# no redirect follow
$resp = Invoke-WebRequest "$base/Admin/Employees/History/$id" -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue
Write-Output "STATUS=$($resp.StatusCode)"
if($resp.Headers['Location']){ Write-Output "LOCATION=$($resp.Headers['Location'])" }

# print first 10 links containing Employees
$content = $resp.Content
if($content){
  [regex]::Matches($content, 'href="([^"]*Employees[^"]*)"') | Select-Object -First 10 | ForEach-Object { $_.Groups[1].Value }
}
