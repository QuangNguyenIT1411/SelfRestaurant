$ErrorActionPreference = 'Stop'
$base = 'http://localhost:5100'
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
function Token([string]$html){ $m=[regex]::Match($html,'name="__RequestVerificationToken"[^>]*value="([^"]+)"','IgnoreCase'); if(-not $m.Success){ throw 'token missing' }; $m.Groups[1].Value }
$loginPage = Invoke-WebRequest -Uri "$base/Staff/Account/Login" -WebSession $session -UseBasicParsing
$token = Token $loginPage.Content
$null = Invoke-WebRequest -Uri "$base/Staff/Account/Login" -Method Post -WebSession $session -UseBasicParsing -ContentType 'application/x-www-form-urlencoded' -Body @{ Username='admin'; Password='123456'; __RequestVerificationToken=$token }
$paths = @('/Admin/Dashboard','/Admin/Categories','/Admin/Ingredients','/Admin/Dishes','/Admin/Customers','/Admin/Employees','/Admin/Reports/Revenue','/Admin/Reports/TopDishes','/Admin/Settings','/Admin/Tables')
foreach($p in $paths){ try { $r = Invoke-WebRequest -Uri ($base + $p) -WebSession $session -UseBasicParsing; Write-Host "$p => $($r.StatusCode)" } catch { Write-Host "$p => ERROR $($_.Exception.Message)" } }
