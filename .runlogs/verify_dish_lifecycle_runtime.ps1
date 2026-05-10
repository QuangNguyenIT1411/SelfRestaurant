$ErrorActionPreference = 'Stop'
$base = 'http://localhost:5100'

function New-Session { New-Object Microsoft.PowerShell.Commands.WebRequestSession }
function Post-Json($session, $url, $body) {
  Invoke-RestMethod -Method Post -Uri $url -WebSession $session -ContentType 'application/json' -Body ($body | ConvertTo-Json -Depth 10)
}
function Delete-Json($session, $url) {
  Invoke-RestMethod -Method Delete -Uri $url -WebSession $session
}
function Get-Json($session, $url) {
  if ($null -eq $session) {
    return Invoke-RestMethod -Method Get -Uri $url
  }
  return Invoke-RestMethod -Method Get -Uri $url -WebSession $session
}
function Try-Invoke($scriptBlock) {
  try { return & $scriptBlock } catch {
    $response = $_.Exception.Response
    if ($null -ne $response) {
      $stream = $response.GetResponseStream()
      $reader = New-Object System.IO.StreamReader($stream)
      $body = $reader.ReadToEnd()
      return [pscustomobject]@{ __error = $true; StatusCode = [int]$response.StatusCode; Body = $body }
    }
    throw
  }
}
function Get-FirstAvailableTableContext($session, $branchId) {
  $tablesResponse = Get-Json $session "$base/api/gateway/customer/branches/$branchId/tables"
  $table = @($tablesResponse.tables | Where-Object { $_.isAvailable } | Select-Object -First 1)
  if ($null -eq $table -or $table.Count -eq 0) {
    return $null
  }

  $ctx = Post-Json $session "$base/api/gateway/customer/context/table" @{ branchId = $branchId; tableId = [int]$table[0].tableId }
  $menu = Get-Json $session "$base/api/gateway/customer/menu"
  return [pscustomobject]@{
    branchId = $branchId
    tableId = [int]$table[0].tableId
    menu = $menu
  }
}
function Get-AllMenuDishes($menu) {
  $items = @()
  foreach ($category in @($menu.categories)) {
    foreach ($dish in @($category.dishes)) {
      $items += $dish
    }
  }
  return $items
}

$admin = New-Session
$chef = New-Session
$customer = New-Session

$adminLogin = Post-Json $admin "$base/api/gateway/staff/auth/login" @{ username = 'admin'; password = '123456' }
$chefLogin = Post-Json $chef "$base/api/gateway/staff/auth/login" @{ username = 'chef_hung'; password = '123456' }
$customerLogin = Post-Json $customer "$base/api/gateway/customer/auth/login" @{ username = 'lan.nguyen'; password = '123456' }

$chefMenu = Get-Json $chef "$base/api/gateway/staff/chef/menu"
$chefBranchId = [int]$chefMenu.branchId
$chefBranchContext = Get-FirstAvailableTableContext $customer $chefBranchId
if ($null -eq $chefBranchContext) {
  throw "No available table found for chef branch $chefBranchId."
}

$menuBefore = $chefBranchContext.menu
$visibleDishes = @(Get-AllMenuDishes $menuBefore)

$safeDish = $null
foreach ($dish in $visibleDishes) {
  if ($dish.name -notlike 'DEL_RT_*') { continue }
  $ref = Get-Json $null "http://localhost:5102/api/internal/dishes/$($dish.dishId)/references"
  if (-not $ref.hasHistory) {
    $safeDish = [pscustomobject]@{
      dishId = [int]$dish.dishId
      name = [string]$dish.name
    }
    break
  }
}
if ($null -eq $safeDish) {
  throw 'No visible test dish DEL_RT_* without history found for safe delete verification.'
}

$safeDishId = $safeDish.dishId
$safeDishName = $safeDish.name
$safeDishPresentBeforeDelete = @($visibleDishes | Where-Object { $_.dishId -eq $safeDishId }).Count -gt 0

$pauseOff = Post-Json $admin "$base/api/gateway/admin/dishes/$safeDishId/availability" @{ available = $false }
$menuAfterPause = Get-Json $customer "$base/api/gateway/customer/menu"
$pausedDishState = @((Get-AllMenuDishes $menuAfterPause) | Where-Object { $_.dishId -eq $safeDishId } | Select-Object -First 1)

$deleteSafeResponse = Delete-Json $admin "$base/api/gateway/admin/dishes/$safeDishId"
$menuAfterDelete = Get-Json $customer "$base/api/gateway/customer/menu"
$safeDishAfterDelete = @((Get-AllMenuDishes $menuAfterDelete) | Where-Object { $_.dishId -eq $safeDishId })

$referencedDish = $null
$adminDishPage = Get-Json $admin "$base/api/gateway/admin/dishes?page=1&pageSize=100&includeInactive=true"
foreach ($dish in $adminDishPage.dishes.items) {
  $dishId = [int]$dish.dishId
  $ref = Get-Json $null "http://localhost:5102/api/internal/dishes/$dishId/references"
  if ($ref.hasHistory) {
    $referencedDish = [pscustomobject]@{ dishId = $dishId; name = $dish.name; refs = $ref }
    break
  }
}
if ($null -eq $referencedDish) { throw 'No referenced dish found for conflict test.' }

$deleteConflict = Try-Invoke { Delete-Json $admin "$base/api/gateway/admin/dishes/$($referencedDish.dishId)" }

$result = [pscustomobject]@{
  adminLoginSuccess = [bool]$adminLogin.success
  chefLoginSuccess = [bool]$chefLogin.success
  customerLoginSuccess = [bool]$customerLogin.success
  chefBranchId = $chefBranchContext.branchId
  chefBranchTableId = $chefBranchContext.tableId
  safeDishId = $safeDishId
  safeDishName = $safeDishName
  safeDishPresentBeforeDelete = $safeDishPresentBeforeDelete
  deleteSafeMessage = $deleteSafeResponse.message
  safeDishVisibleAfterDelete = ($safeDishAfterDelete.Count -gt 0)
  pauseDishId = $safeDishId
  pauseDishName = $safeDishName
  pauseOffMessage = $pauseOff.message
  pauseDishStillVisible = ($pausedDishState.Count -gt 0)
  pauseDishAvailableAfterPause = if ($pausedDishState.Count -gt 0) { [bool]$pausedDishState[0].available } else { $null }
  referencedDishId = $referencedDish.dishId
  referencedDishName = $referencedDish.name
  referencedDishOrderItemCount = $referencedDish.refs.orderItemCount
  deleteConflictStatus = if ($deleteConflict.__error) { $deleteConflict.StatusCode } else { 200 }
  deleteConflictBody = if ($deleteConflict.__error) { $deleteConflict.Body } else { ($deleteConflict | ConvertTo-Json -Depth 10 -Compress) }
}
$result | ConvertTo-Json -Depth 10
