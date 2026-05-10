$ErrorActionPreference = 'Stop'

function Get-Json($url, $session) {
  return Invoke-RestMethod -Uri $url -WebSession $session -TimeoutSec 30
}

function Post-Json($url, $body, $session) {
  return Invoke-RestMethod -Method Post -Uri $url -WebSession $session -Body ($body | ConvertTo-Json) -ContentType 'application/json' -TimeoutSec 30
}

$root = 'http://localhost:5100'
$customerSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$chefSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$cashierSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$adminSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession

$health = 5100..5105 | ForEach-Object {
  [pscustomobject]@{
    Port = $_
    Status = (Invoke-WebRequest -Uri ("http://localhost:{0}/healthz" -f $_) -UseBasicParsing -TimeoutSec 20).StatusCode
  }
}

$branch1 = Get-Json "$root/api/gateway/customer/branches/1/tables" $customerSession
$branch2 = Get-Json "$root/api/gateway/customer/branches/2/tables" $customerSession
$branch1Table1 = $branch1.tables | Where-Object { $_.displayTableNumber -eq 1 } | Select-Object -First 1
$branch2Table1 = $branch2.tables | Where-Object { $_.displayTableNumber -eq 1 } | Select-Object -First 1
$branch2Available = $branch2.tables | Where-Object { $_.isAvailable } | Sort-Object displayTableNumber, tableId | Select-Object -First 1
$qrLookup = Get-Json "$root/api/gateway/customer/tables/qr/QR-GV-B01" $customerSession

$setContext = Post-Json "$root/api/gateway/customer/context/table" @{
  tableId = $branch2Available.tableId
  branchId = $branch2Available.branchId
} $customerSession
$session = Get-Json "$root/api/gateway/customer/session" $customerSession
$menu = Get-Json "$root/api/gateway/customer/menu" $customerSession

$adminLogin = Post-Json "$root/api/gateway/staff/auth/login" @{ username = 'admin'; password = '123456' } $adminSession
$adminTables = Get-Json "$root/api/gateway/admin/tables?page=1&pageSize=5" $adminSession

$cashierLogin = Post-Json "$root/api/gateway/staff/auth/login" @{ username = 'cashier_lan'; password = '123456' } $cashierSession
$cashierDashboard = Get-Json "$root/api/gateway/staff/cashier/dashboard" $cashierSession

$chefLogin = Post-Json "$root/api/gateway/staff/auth/login" @{ username = 'chef_hung'; password = '123456' } $chefSession
$chefDashboard = Get-Json "$root/api/gateway/staff/chef/dashboard" $chefSession
$chefHistory = Get-Json "$root/api/gateway/staff/chef/history?take=10" $chefSession

$result = [pscustomobject]@{
  health = $health
  branch1FirstTables = $branch1.tables | Select-Object -First 3
  branch2FirstTables = $branch2.tables | Select-Object -First 3
  branch1HasTable1 = $null -ne $branch1Table1
  branch2HasTable1 = $null -ne $branch2Table1
  branch1Table1Physical = $branch1Table1
  branch2Table1Physical = $branch2Table1
  qrLookup = $qrLookup
  setContext = $setContext
  sessionTableContext = $session.tableContext
  menuTableContext = $menu.tableContext
  menuBranchName = $menu.menu.branchName
  menuCategoryCount = $menu.menu.categories.Count
  adminNextPath = $adminLogin.nextPath
  adminTablesPage = $adminTables.tables.items | Select-Object -First 5
  cashierNextPath = $cashierLogin.nextPath
  cashierTableCards = $cashierDashboard.tables | Select-Object -First 5
  chefNextPath = $chefLogin.nextPath
  chefPendingOrders = $chefDashboard.pendingOrders | Select-Object -First 5
  chefHistory = $chefHistory | Select-Object -First 5
}

$result | ConvertTo-Json -Depth 8
