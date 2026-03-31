$s = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$lp = Invoke-WebRequest 'https://localhost:7100/Customer/Login?mode=login&force=true' -WebSession $s -UseBasicParsing
$match = [regex]::Match($lp.Content, 'name="__RequestVerificationToken"[^>]*value="([^"]+)"')
$lt = $match.Groups[1].Value
$r = Invoke-WebRequest 'https://localhost:7100/Customer/Login' -Method Post -WebSession $s -UseBasicParsing -Headers @{ 'X-Requested-With'='XMLHttpRequest' } -Body @{
  __RequestVerificationToken = $lt
  mode = 'login'
  'Login.Username' = 'lan.nguyen'
  'Login.Password' = '123456'
  'Login.ReturnUrl' = ''
}
$tb = Invoke-WebRequest 'https://localhost:7100/Home/GetBranchTables?branchId=1' -WebSession $s -UseBasicParsing
$tj = $tb.Content | ConvertFrom-Json
$pick = $tj.tables | Where-Object { $_.isAvailable -eq $true } | Select-Object -First 1
if (-not $pick) { $pick = $tj.tables | Select-Object -First 1 }
$url = 'https://localhost:7100/Menu/Index?tableId=' + $pick.tableId + '&branchId=1&tableNumber=' + $pick.displayTableNumber
$m = Invoke-WebRequest $url -WebSession $s -UseBasicParsing
Set-Content -Path .runlogs/menu_live_dump.html -Value $m.Content -Encoding UTF8
if ($m.Content -match '__RequestVerificationToken') { 'TOKEN_PRESENT' } else { 'TOKEN_MISSING' }
