$ErrorActionPreference = 'Stop'
$catalog = 'http://localhost:5101'
$orders = 'http://localhost:5102'
$gateway = 'http://localhost:5100'

$branches = Invoke-RestMethod -Uri "$catalog/api/branches" -Method Get
$branchId = ($branches | Select-Object -First 1).branchId
$tables = Invoke-RestMethod -Uri "$catalog/api/branches/$branchId/tables" -Method Get
$table = ($tables.tables | Select-Object -First 1)
$menu = Invoke-RestMethod -Uri "$catalog/api/branches/$branchId/menu" -Method Get
$dish = $null
foreach ($category in $menu.categories) {
  $dish = $category.dishes | Where-Object { $_.available } | Select-Object -First 1
  if ($dish) { break }
}
if (-not $dish) { throw 'No available dish found for chef smoke test.' }

Invoke-RestMethod -Uri "$orders/api/tables/$($table.tableId)/occupy" -Method Post -ContentType 'application/json' -Body '{}' | Out-Null
$order = Invoke-RestMethod -Uri "$orders/api/tables/$($table.tableId)/order/items" -Method Post -ContentType 'application/json' -Body (@{ dishId = $dish.dishId; quantity = 1; note = 'Chef lane smoke' } | ConvertTo-Json)
Invoke-RestMethod -Uri "$orders/api/tables/$($table.tableId)/order/submit" -Method Post -ContentType 'application/json' -Body '{}' | Out-Null
$orderId = $order.orderId
$itemId = ($order.items | Select-Object -First 1).itemId

$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$login = Invoke-RestMethod -Uri "$gateway/api/gateway/staff/auth/login" -WebSession $session -Method Post -ContentType 'application/json' -Body (@{ username='chef_hung'; password='123456' } | ConvertTo-Json)
$staffSession = Invoke-RestMethod -Uri "$gateway/api/gateway/staff/session" -WebSession $session -Method Get
$dashboard1 = Invoke-RestMethod -Uri "$gateway/api/gateway/staff/chef/dashboard" -WebSession $session -Method Get
$noteResult = Invoke-RestMethod -Uri "$gateway/api/gateway/staff/chef/orders/$orderId/items/$itemId/note" -WebSession $session -Method Patch -ContentType 'application/json' -Body (@{ note='Chef updated note'; append=$false } | ConvertTo-Json)
$start = Invoke-RestMethod -Uri "$gateway/api/gateway/staff/chef/orders/$orderId/start" -WebSession $session -Method Post -ContentType 'application/json' -Body '{}'
$ready = Invoke-RestMethod -Uri "$gateway/api/gateway/staff/chef/orders/$orderId/ready" -WebSession $session -Method Post -ContentType 'application/json' -Body '{}'
$serve = Invoke-RestMethod -Uri "$gateway/api/gateway/staff/chef/orders/$orderId/serve" -WebSession $session -Method Post -ContentType 'application/json' -Body '{}'
$dashboard2 = Invoke-RestMethod -Uri "$gateway/api/gateway/staff/chef/dashboard" -WebSession $session -Method Get
$ingredients = Invoke-RestMethod -Uri "$gateway/api/gateway/staff/chef/dishes/$($dish.dishId)/ingredients" -WebSession $session -Method Get
$saveIngredients = Invoke-RestMethod -Uri "$gateway/api/gateway/staff/chef/dishes/$($dish.dishId)/ingredients" -WebSession $session -Method Put -ContentType 'application/json' -Body (@{ items = @($ingredients.items) } | ConvertTo-Json -Depth 6)
$hide = Invoke-RestMethod -Uri "$gateway/api/gateway/staff/chef/dishes/$($dish.dishId)/availability" -WebSession $session -Method Post -ContentType 'application/json' -Body (@{ available = $false } | ConvertTo-Json)
$show = Invoke-RestMethod -Uri "$gateway/api/gateway/staff/chef/dishes/$($dish.dishId)/availability" -WebSession $session -Method Post -ContentType 'application/json' -Body (@{ available = $true } | ConvertTo-Json)
[pscustomobject]@{
  BranchId = $branchId
  TableId = $table.tableId
  DishId = $dish.dishId
  OrderId = $orderId
  LoginOk = $login.success
  RoleCode = $staffSession.staff.roleCode
  PendingCount = @($dashboard1.pendingOrders).Count
  NoteMessage = $noteResult.message
  StartMessage = $start.message
  ReadyMessage = $ready.message
  ServeMessage = $serve.message
  HistoryCount = @($dashboard2.history).Count
  IngredientsCount = @($ingredients.items).Count
  HideAvailable = $hide.available
  ShowAvailable = $show.available
} | ConvertTo-Json -Depth 5
