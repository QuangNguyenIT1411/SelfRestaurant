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

$rows = @()
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
        $img = [string]$d.Image
        $status = ''
        $isBroken = $false

        if ($img -match '^https?://') {
          try {
            $resp = Invoke-WebRequest -Uri $img -Method Head -UseBasicParsing -TimeoutSec 8
            $status = [string]$resp.StatusCode
            if ($resp.StatusCode -lt 200 -or $resp.StatusCode -ge 400) { $isBroken = $true }
          } catch {
            $status = 'ERR'
            $isBroken = $true
          }
        } else {
          $url = "$base$img"
          try {
            $resp = Invoke-WebRequest -Uri $url -Method Head -UseBasicParsing -TimeoutSec 8
            $status = [string]$resp.StatusCode
            if ($resp.StatusCode -lt 200 -or $resp.StatusCode -ge 400) { $isBroken = $true }
          } catch {
            $status = 'ERR'
            $isBroken = $true
          }
        }

        $rows += [pscustomobject]@{
          BranchId = $branchId
          DishId = $d.DishID
          DishName = $d.Name
          Category = $c.CategoryName
          Image = $img
          HttpStatus = $status
          Broken = $isBroken
        }
      }
    }
  } catch {
    continue
  }
}

$rows = $rows | Sort-Object BranchId,DishName,DishId -Unique
$broken = @($rows | Where-Object { $_.Broken })
Write-Output "TOTAL=$($rows.Count)"
Write-Output "BROKEN=$($broken.Count)"
$broken | Format-Table -AutoSize
Write-Output "\nFILTER_FLAN_AND_DRINKS:"
$rows | Where-Object { $_.DishName -match 'Flan|flan|nuoc|cam|sinh|tra|ep|juice|bo' } | Sort-Object DishName,BranchId | Format-Table -AutoSize
