$ErrorActionPreference='Stop'

function New-DbConnection([string]$Database) {
  $conn = New-Object System.Data.SqlClient.SqlConnection("Server=(localdb)\MSSQLLocalDB;Database=$Database;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=True")
  $conn.Open()
  return $conn
}

function Invoke-DbNonQuery {
  param(
    [System.Data.SqlClient.SqlConnection]$Connection,
    [string]$Sql
  )
  $cmd = $Connection.CreateCommand()
  $cmd.CommandText = $Sql
  $cmd.CommandTimeout = 60
  [void]$cmd.ExecuteNonQuery()
}

function Invoke-DbScalar {
  param(
    [System.Data.SqlClient.SqlConnection]$Connection,
    [string]$Sql
  )
  $cmd = $Connection.CreateCommand()
  $cmd.CommandText = $Sql
  $cmd.CommandTimeout = 60
  return $cmd.ExecuteScalar()
}

function Read-ErrorResponse($Exception) {
  $response = $Exception.Response
  if ($null -eq $response) { return [pscustomobject]@{ raw = $Exception.Message; status = 0; json = $null } }
  $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
  $raw = $reader.ReadToEnd()
  $reader.Close()
  $json = $null
  if (-not [string]::IsNullOrWhiteSpace($raw)) { try { $json = $raw | ConvertFrom-Json } catch {} }
  [pscustomobject]@{ raw = $raw; status = [int]$response.StatusCode; json = $json }
}

function Invoke-RestApi {
  param([string]$Method='GET',[string]$Url,$Session,$Body=$null)
  $params = @{ Uri=$Url; Method=$Method; TimeoutSec=60 }
  if ($null -ne $Session) { $params.WebSession = $Session }
  if ($null -ne $Body) { $params.ContentType='application/json'; $params.Body=($Body|ConvertTo-Json -Depth 20) }
  try {
    $json = Invoke-RestMethod @params
    return [pscustomobject]@{ ok=$true; status=200; json=$json }
  } catch {
    $err = Read-ErrorResponse $_.Exception
    return [pscustomobject]@{ ok=$false; status=$err.status; json=$err.json; raw=$err.raw }
  }
}

$base='http://localhost:5100'
$marker = 'READY_ACK_VERIFY_' + (Get-Date -Format 'yyyyMMddHHmmss')
$customerSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$chefSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$ordersConn = $null
$customersConn = $null
$catalogConn = $null
$createdOrderId = $null
$createdTableId = $null
$createdItemId = $null

try {
  $customerLogin = Invoke-RestApi -Method POST -Url "$base/api/gateway/customer/auth/login" -Session $customerSession -Body @{ username='lan.nguyen'; password='123456' }
  if (-not $customerLogin.ok) { throw "Customer login failed: $($customerLogin.raw)" }

  [void](Invoke-RestApi -Method DELETE -Url "$base/api/gateway/customer/context/table" -Session $customerSession)

  $branchTables = Invoke-RestApi -Url "$base/api/gateway/customer/branches/1/tables" -Session $customerSession
  if (-not $branchTables.ok) { throw "Load branch tables failed: $($branchTables.raw)" }
  $selectedTable = @($branchTables.json.tables | Where-Object { $_.isAvailable }) | Select-Object -First 1
  if ($null -eq $selectedTable) { throw 'No available table found for runtime verification.' }
  $createdTableId = [int]$selectedTable.tableId

  $setContext = Invoke-RestApi -Method POST -Url "$base/api/gateway/customer/context/table" -Session $customerSession -Body @{ tableId=$createdTableId; branchId=1 }
  if (-not $setContext.ok) { throw "Set table context failed: $($setContext.raw)" }

  $menu = Invoke-RestApi -Url "$base/api/gateway/customer/menu" -Session $customerSession
  if (-not $menu.ok) { throw "Load menu failed: $($menu.raw)" }
  $dish = @($menu.json.menu.categories | ForEach-Object { $_.dishes } | Where-Object { $_.available }) | Select-Object -First 1
  if ($null -eq $dish) { throw 'No available dish found for runtime verification.' }

  $addItem = Invoke-RestApi -Method POST -Url "$base/api/gateway/customer/order/items" -Session $customerSession -Body @{
    dishId = [int]$dish.dishId
    quantity = 1
    note = $marker
  }
  if (-not $addItem.ok) { throw "Add item failed: $($addItem.raw)" }

  $submitKey = [guid]::NewGuid().ToString('N')
  $submit = Invoke-RestApi -Method POST -Url "$base/api/gateway/customer/order/submit" -Session $customerSession -Body @{
    idempotencyKey = $submitKey
    expectedDiningSessionCode = $null
  }
  if (-not $submit.ok) { throw "Submit order failed: $($submit.raw)" }

  $orderAfterSubmit = Invoke-RestApi -Url "$base/api/gateway/customer/order" -Session $customerSession
  if (-not $orderAfterSubmit.ok) { throw "Load order after submit failed: $($orderAfterSubmit.raw)" }
  $createdOrderId = [int]$orderAfterSubmit.json.orderId
  $createdItemId = [int]((@($orderAfterSubmit.json.items | Where-Object { $_.dishId -eq $dish.dishId }) | Select-Object -First 1).itemId)

  $chefLogin = Invoke-RestApi -Method POST -Url "$base/api/gateway/staff/auth/login" -Session $chefSession -Body @{ username='chef_hung'; password='123456' }
  if (-not $chefLogin.ok) { throw "Chef login failed: $($chefLogin.raw)" }

  $chefStart = Invoke-RestApi -Method POST -Url "$base/api/gateway/staff/chef/orders/$createdOrderId/items/$createdItemId/start" -Session $chefSession -Body @{}
  if (-not $chefStart.ok) { throw "Chef start item failed: $($chefStart.raw)" }
  $chefReady = Invoke-RestApi -Method POST -Url "$base/api/gateway/staff/chef/orders/$createdOrderId/items/$createdItemId/ready" -Session $chefSession -Body @{}
  if (-not $chefReady.ok) { throw "Chef ready item failed: $($chefReady.raw)" }

  Start-Sleep -Seconds 3

  $beforeConfirmNotifications = Invoke-RestApi -Url "$base/api/gateway/customer/ready-notifications" -Session $customerSession
  $beforeConfirmOrder = Invoke-RestApi -Url "$base/api/gateway/customer/order" -Session $customerSession
  if (-not $beforeConfirmNotifications.ok) { throw "Load ready notifications before confirm failed: $($beforeConfirmNotifications.raw)" }
  if (-not $beforeConfirmOrder.ok) { throw "Load order before confirm failed: $($beforeConfirmOrder.raw)" }

  $confirmReceived = Invoke-RestApi -Method POST -Url "$base/api/gateway/customer/order/confirm-received?orderId=$createdOrderId" -Session $customerSession
  if (-not $confirmReceived.ok -and $confirmReceived.status -ne 204) { throw "Confirm received failed: $($confirmReceived.raw)" }

  $notificationId = @($beforeConfirmNotifications.json.items | Where-Object { $_.orderId -eq $createdOrderId } | Select-Object -First 1).notificationId
  if ($notificationId) {
    $resolve = Invoke-RestApi -Method POST -Url "$base/api/gateway/customer/ready-notifications/$notificationId/resolve" -Session $customerSession
    if (-not $resolve.ok) { throw "Resolve ready notification failed: $($resolve.raw)" }
  }

  Start-Sleep -Seconds 1

  $afterReloadMenu = Invoke-RestApi -Url "$base/api/gateway/customer/menu" -Session $customerSession
  $afterReloadOrder = Invoke-RestApi -Url "$base/api/gateway/customer/order" -Session $customerSession
  $afterReloadOrderItems = Invoke-RestApi -Url "$base/api/gateway/customer/order/items" -Session $customerSession
  $afterReloadReadyNotifications = Invoke-RestApi -Url "$base/api/gateway/customer/ready-notifications" -Session $customerSession

  $ordersConn = New-DbConnection 'RESTAURANT_ORDERS'
  $customersConn = New-DbConnection 'RESTAURANT_CUSTOMERS'
  $catalogConn = New-DbConnection 'RESTAURANT_CATALOG'

  $dbReadyCount = [int](Invoke-DbScalar -Connection $customersConn -Sql "SELECT COUNT(*) FROM ReadyDishNotifications WHERE OrderId = $createdOrderId AND Status = 'OPEN';")
  $dbResolvedCount = [int](Invoke-DbScalar -Connection $customersConn -Sql "SELECT COUNT(*) FROM ReadyDishNotifications WHERE OrderId = $createdOrderId AND Status = 'RESOLVED';")
  $dbServingCount = [int](Invoke-DbScalar -Connection $ordersConn -Sql "SELECT COUNT(*) FROM OrderItems WHERE OrderID = $createdOrderId AND StatusCode = 'SERVING';")
  $dbReadyItemCount = [int](Invoke-DbScalar -Connection $ordersConn -Sql "SELECT COUNT(*) FROM OrderItems WHERE OrderID = $createdOrderId AND StatusCode = 'READY';")

  $bundlePath = Get-ChildItem -Path 'src/Frontend/selfrestaurant-customer-web/dist/assets' -Filter 'index-*.js' |
    Sort-Object LastWriteTimeUtc -Descending |
    Select-Object -First 1
  $bundleText = if ($bundlePath) { Get-Content -Path $bundlePath.FullName -Raw } else { '' }

  [ordered]@{
    marker = $marker
    selectedTableId = $createdTableId
    createdOrderId = $createdOrderId
    createdItemId = $createdItemId
    beforeConfirm = [ordered]@{
      readyNotificationCount = @($beforeConfirmNotifications.json.items).Count
      readyNotificationOrderIds = @($beforeConfirmNotifications.json.items | ForEach-Object { $_.orderId })
      orderItemStatuses = @($beforeConfirmOrder.json.items | Select-Object itemId, status)
    }
    afterReopen = [ordered]@{
      menuOk = $afterReloadMenu.ok
      orderOk = $afterReloadOrder.ok
      orderItemsOk = $afterReloadOrderItems.ok
      readyNotificationsOk = $afterReloadReadyNotifications.ok
      orderStatus = $afterReloadOrder.json.statusCode
      orderItemStatuses = @($afterReloadOrderItems.json.items | Select-Object itemId, orderId, dishName, status)
      readyNotificationCount = @($afterReloadReadyNotifications.json.items).Count
    }
    database = [ordered]@{
      openReadyNotifications = $dbReadyCount
      resolvedReadyNotifications = $dbResolvedCount
      servingItems = $dbServingCount
      readyItems = $dbReadyItemCount
    }
    bundleEvidence = [ordered]@{
      distBundle = if ($bundlePath) { $bundlePath.Name } else { $null }
      treatsServingAsReady = $bundleText -match 'SERVING[\s\S]{0,200}ready'
      treatsServingAsReceived = $bundleText -match 'SERVING[\s\S]{0,200}received'
    }
  } | ConvertTo-Json -Depth 10
}
finally {
  if ($createdOrderId) {
    if ($customersConn -and $customersConn.State -eq [System.Data.ConnectionState]::Open) {
      Invoke-DbNonQuery -Connection $customersConn -Sql "DELETE FROM ReadyDishNotifications WHERE OrderId = $createdOrderId;"
      Invoke-DbNonQuery -Connection $customersConn -Sql @"
DELETE FROM InboxEvents
WHERE PayloadJson LIKE '%"orderId":$createdOrderId%';
"@
    }

    if ($ordersConn -and $ordersConn.State -eq [System.Data.ConnectionState]::Open) {
      Invoke-DbNonQuery -Connection $ordersConn -Sql "DELETE FROM BusinessAuditLogs WHERE OrderId = $createdOrderId;"
      Invoke-DbNonQuery -Connection $ordersConn -Sql "DELETE FROM SubmitCommands WHERE OrderId = $createdOrderId;"
      Invoke-DbNonQuery -Connection $ordersConn -Sql @"
DELETE FROM OutboxEvents
WHERE PayloadJson LIKE '%"orderId":$createdOrderId%';
"@
      Invoke-DbNonQuery -Connection $ordersConn -Sql "DELETE FROM OrderItems WHERE OrderID = $createdOrderId;"
      Invoke-DbNonQuery -Connection $ordersConn -Sql "DELETE FROM Orders WHERE OrderID = $createdOrderId;"
    }

    if ($catalogConn -and $catalogConn.State -eq [System.Data.ConnectionState]::Open -and $createdTableId) {
      Invoke-DbNonQuery -Connection $catalogConn -Sql @"
UPDATE t
SET t.CurrentOrderID = NULL,
    t.StatusID = s.StatusID,
    t.UpdatedAt = GETDATE()
FROM DiningTables t
CROSS APPLY (
  SELECT TOP 1 StatusID
  FROM TableStatus
  WHERE StatusCode = 'AVAILABLE'
) s
WHERE t.TableID = $createdTableId AND t.CurrentOrderID = $createdOrderId;
"@
    }
  }

  if ($ordersConn -and $ordersConn.State -eq [System.Data.ConnectionState]::Open) { $ordersConn.Close() }
  if ($customersConn -and $customersConn.State -eq [System.Data.ConnectionState]::Open) { $customersConn.Close() }
  if ($catalogConn -and $catalogConn.State -eq [System.Data.ConnectionState]::Open) { $catalogConn.Close() }
}
