$ErrorActionPreference = 'Stop'
$base = 'http://localhost:5100'
$branchIds = @(1,2,3)
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

$all = @()
foreach ($branchId in $branchIds) {
  try {
    $tb = Invoke-WebRequest "$base/Home/GetBranchTables?branchId=$branchId" -WebSession $s -UseBasicParsing
    $tj = $tb.Content | ConvertFrom-Json
    if (-not $tj.success -or -not $tj.tables -or $tj.tables.Count -eq 0) { continue }
    $pick = $tj.tables | Select-Object -First 1

    $menu = Invoke-WebRequest "$base/Menu/Index?tableId=$($pick.tableId)&branchId=$branchId&tableNumber=$($pick.displayTableNumber)" -WebSession $s -UseBasicParsing
    $m = [regex]::Match($menu.Content, 'const categories = (.*?);\s*const tableNumber', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if (-not $m.Success) { continue }

    $categories = $m.Groups[1].Value | ConvertFrom-Json
    foreach ($c in $categories) {
      foreach ($d in $c.Dishes) {
        $all += [pscustomobject]@{
          BranchId = $branchId
          Category = $c.CategoryName
          DishId = $d.DishID
          Name = $d.Name
          Image = $d.Image
          IsPlaceholder = ($d.Image -eq '/images/placeholder-dish.svg')
        }
      }
    }
  } catch {
    continue
  }
}

$all = $all | Sort-Object Name,BranchId -Unique
"TOTAL_DISHES=$($all.Count)"
"PLACEHOLDER_COUNT=$((@($all | Where-Object { $_.IsPlaceholder })).Count)"
$all | Format-Table -AutoSize
