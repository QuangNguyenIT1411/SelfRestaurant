$base='http://localhost:5100'
$s=New-Object Microsoft.PowerShell.Commands.WebRequestSession
function tok($h){([regex]::Match($h,'name="__RequestVerificationToken"[^>]*value="([^"]+)"',[System.Text.RegularExpressions.RegexOptions]::IgnoreCase)).Groups[1].Value}
$lp=Invoke-WebRequest "$base/Staff/Account/Login" -WebSession $s -UseBasicParsing
$t=tok $lp.Content
$r=Invoke-WebRequest "$base/Staff/Account/Login" -Method Post -WebSession $s -UseBasicParsing -Headers @{ 'X-Requested-With'='XMLHttpRequest' } -Body @{__RequestVerificationToken=$t;username='admin';password='123456';rememberMe='false'}

$cat=Invoke-WebRequest "$base/Admin/Categories" -WebSession $s -UseBasicParsing
$emp=Invoke-WebRequest "$base/Admin/Employees?search=autoemp2_" -WebSession $s -UseBasicParsing
$tab=Invoke-WebRequest "$base/Admin/Tables?search=AUTO-QR2-" -WebSession $s -UseBasicParsing

$cat.Content | Set-Content -Encoding UTF8 .runlogs/debug_categories_latest.html
$emp.Content | Set-Content -Encoding UTF8 .runlogs/debug_employees_latest.html
$tab.Content | Set-Content -Encoding UTF8 .runlogs/debug_tables_latest.html

Write-Output '=== categories hidden id samples ==='
[regex]::Matches($cat.Content,'<input[^>]*type="hidden"[^>]*>',[System.Text.RegularExpressions.RegexOptions]::IgnoreCase) | Select-Object -First 20 | ForEach-Object { $_.Value }
Write-Output '=== employees edit links samples ==='
[regex]::Matches($emp.Content,'/Admin/Employees/Edit/[0-9]+',[System.Text.RegularExpressions.RegexOptions]::IgnoreCase) | Select-Object -First 20 | ForEach-Object { $_.Value }
Write-Output '=== tables edit links samples ==='
[regex]::Matches($tab.Content,'/Admin/Tables/Edit/[0-9]+',[System.Text.RegularExpressions.RegexOptions]::IgnoreCase) | Select-Object -First 20 | ForEach-Object { $_.Value }
