$base = 'http://localhost:5100'
$s = New-Object Microsoft.PowerShell.Commands.WebRequestSession

$lp = Invoke-WebRequest "$base/Customer/Login?mode=login&force=true" -WebSession $s -UseBasicParsing
$tok = [regex]::Match($lp.Content, 'name="__RequestVerificationToken"[^>]*value="([^"]+)"').Groups[1].Value

$lr = Invoke-WebRequest "$base/Customer/Login" -Method Post -WebSession $s -UseBasicParsing -Headers @{ 'X-Requested-With' = 'XMLHttpRequest' } -Body @{
  __RequestVerificationToken = $tok
  mode = 'login'
  'Login.Username' = 'lan.nguyen'
  'Login.Password' = '123456'
  'Login.ReturnUrl' = ''
}

$lj = $lr.Content | ConvertFrom-Json
if (-not $lj.success) {
  Write-Output ("LOGIN_FAIL: " + $lr.Content)
  exit 1
}

$tb = Invoke-WebRequest "$base/Home/GetBranchTables?branchId=1" -WebSession $s -UseBasicParsing
$tj = $tb.Content | ConvertFrom-Json
$pick = $tj.tables | Select-Object -First 1

$menu = Invoke-WebRequest "$base/Menu/Index?tableId=$($pick.tableId)&branchId=1&tableNumber=$($pick.displayTableNumber)" -WebSession $s -UseBasicParsing

$matches = [regex]::Matches($menu.Content, '"Image":"([^"]+)"')
$vals = @()
foreach ($m in $matches) {
  $vals += $m.Groups[1].Value
}
$uniq = $vals | Select-Object -Unique

Write-Output ("COUNT=" + $uniq.Count)
$uniq | Select-Object -First 15
