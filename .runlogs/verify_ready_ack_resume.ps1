$ErrorActionPreference = "Stop"

function New-DbConnection([string]$Database) {
    $conn = New-Object System.Data.SqlClient.SqlConnection("Server=(localdb)\MSSQLLocalDB;Database=$Database;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=True")
    $conn.Open()
    return $conn
}

function Invoke-DbQuery {
    param(
        [Parameter(Mandatory = $true)]
        [System.Data.SqlClient.SqlConnection]$Connection,
        [Parameter(Mandatory = $true)]
        [string]$Sql
    )

    $cmd = $Connection.CreateCommand()
    $cmd.CommandText = $Sql
    $cmd.CommandTimeout = 60
    $reader = $cmd.ExecuteReader()
    $rows = @()
    while ($reader.Read()) {
        $row = [ordered]@{}
        for ($i = 0; $i -lt $reader.FieldCount; $i++) {
            $value = $reader.GetValue($i)
            if ($value -is [System.DBNull]) {
                $value = $null
            }
            $row[$reader.GetName($i)] = $value
        }
        $rows += [pscustomobject]$row
    }
    $reader.Close()
    return $rows
}

function Read-ErrorResponse($Exception) {
    $response = $Exception.Response
    if ($null -eq $response) { return [pscustomobject]@{ raw = $Exception.Message; status = 0; json = $null } }
    $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
    $raw = $reader.ReadToEnd()
    $reader.Close()
    $json = $null
    if (-not [string]::IsNullOrWhiteSpace($raw)) {
        try { $json = $raw | ConvertFrom-Json } catch {}
    }
    [pscustomobject]@{ raw = $raw; status = [int]$response.StatusCode; json = $json }
}

function Invoke-RestApi {
    param([string]$Method = "GET", [string]$Url, $Session, $Body = $null)
    $params = @{ Uri = $Url; Method = $Method; TimeoutSec = 60 }
    if ($null -ne $Session) { $params.WebSession = $Session }
    if ($null -ne $Body) {
        $params.ContentType = "application/json"
        $params.Body = ($Body | ConvertTo-Json -Depth 20)
    }
    try {
        $json = Invoke-RestMethod @params
        return [pscustomobject]@{ ok = $true; status = 200; json = $json }
    } catch {
        $err = Read-ErrorResponse $_.Exception
        return [pscustomobject]@{ ok = $false; status = $err.status; json = $err.json; raw = $err.raw }
    }
}

$ordersConn = New-DbConnection "RESTAURANT_ORDERS"
$customersConn = New-DbConnection "RESTAURANT_CUSTOMERS"
$identityConn = New-DbConnection "RESTAURANT_IDENTITY"

try {
    $candidate = Invoke-DbQuery -Connection $ordersConn -Sql @"
SELECT TOP 1
    o.OrderID,
    o.OrderCode,
    o.CustomerID,
    o.TableID,
    o.DiningSessionCode,
    SUM(CASE WHEN oi.StatusCode = 'READY' THEN 1 ELSE 0 END) AS ReadyCount,
    SUM(CASE WHEN oi.StatusCode = 'SERVING' THEN 1 ELSE 0 END) AS ServingCount,
    SUM(CASE WHEN oi.StatusCode = 'SERVED' THEN 1 ELSE 0 END) AS ServedCount
FROM Orders o
JOIN OrderItems oi ON oi.OrderID = o.OrderID
WHERE (o.IsActive = 1 OR o.IsActive IS NULL)
  AND o.CustomerID IS NOT NULL
 GROUP BY o.OrderID, o.OrderCode, o.CustomerID, o.TableID, o.DiningSessionCode
HAVING SUM(CASE WHEN oi.StatusCode = 'SERVING' THEN 1 ELSE 0 END) > 0
   AND SUM(CASE WHEN oi.StatusCode = 'READY' THEN 1 ELSE 0 END) = 0
ORDER BY o.OrderID DESC
"@ | Select-Object -First 1

    if ($null -eq $candidate) {
        throw "Không tìm thấy order ứng viên ở trạng thái SERVING để kiểm tra bug resume."
    }

    $customer = Invoke-DbQuery -Connection $identityConn -Sql @"
SELECT TOP 1 CustomerID, Username, Name
FROM Customers
WHERE CustomerID = $($candidate.CustomerID)
"@ | Select-Object -First 1

    if ($null -eq $customer) {
        throw "Không tìm thấy customer cho order ứng viên."
    }

    $openNotifications = Invoke-DbQuery -Connection $customersConn -Sql @"
SELECT ReadyDishNotificationId, OrderId, OrderItemId, Status, CreatedAtUtc, ResolvedAtUtc
FROM ReadyDishNotifications
WHERE OrderId = $($candidate.OrderID)
ORDER BY ReadyDishNotificationId DESC
"@

    $openCount = @($openNotifications | Where-Object { $_.Status -eq "OPEN" }).Count
    $resolvedCount = @($openNotifications | Where-Object { $_.Status -eq "RESOLVED" }).Count

    $base = "http://localhost:5100"
    $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession

    $login = Invoke-RestApi -Method POST -Url "$base/api/gateway/customer/auth/login" -Session $session -Body @{
        username = [string]$customer.Username
        password = "123456"
    }
    if (-not $login.ok) {
        throw "Đăng nhập customer kiểm tra thất bại: $($login.raw)"
    }

    $sync = Invoke-RestApi -Method POST -Url "$base/api/gateway/customer/session/sync-active-order" -Session $session
    $menu = Invoke-RestApi -Url "$base/api/gateway/customer/menu" -Session $session
    $order = Invoke-RestApi -Url "$base/api/gateway/customer/order" -Session $session
    $orderItems = Invoke-RestApi -Url "$base/api/gateway/customer/order/items" -Session $session
    $readyNotifications = Invoke-RestApi -Url "$base/api/gateway/customer/ready-notifications" -Session $session

    $bundlePath = Get-ChildItem -Path "src/Frontend/selfrestaurant-customer-web/dist/assets" -Filter "index-*.js" |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 1
    $bundleText = if ($bundlePath) { Get-Content -Path $bundlePath.FullName -Raw } else { "" }

    [ordered]@{
        candidateOrder = $candidate
        customer = $customer
        notificationRows = $openNotifications
        openNotificationCount = $openCount
        resolvedNotificationCount = $resolvedCount
        login = [ordered]@{ ok = $login.ok; status = $login.status }
        sessionSync = [ordered]@{ ok = $sync.ok; status = $sync.status; session = $sync.json }
        menu = [ordered]@{
            ok = $menu.ok
            status = $menu.status
            branchName = $menu.json.menu.branchName
            tableId = $menu.json.tableContext.tableId
        }
        order = [ordered]@{
            ok = $order.ok
            status = $order.status
            orderId = $order.json.orderId
            orderStatus = $order.json.statusCode
            activeOrderIds = $order.json.activeOrderIds
        }
        orderItems = [ordered]@{
            ok = $orderItems.ok
            status = $orderItems.status
            items = $orderItems.json.items | Select-Object itemId, orderId, dishName, status
        }
        readyNotifications = [ordered]@{
            ok = $readyNotifications.ok
            status = $readyNotifications.status
            count = @($readyNotifications.json.items).Count
            items = $readyNotifications.json.items
        }
        bundleEvidence = [ordered]@{
            distBundle = if ($bundlePath) { $bundlePath.Name } else { $null }
            treatsServingAsReady = $bundleText -match 'status==="SERVING"\)return"ready"'
            treatsServingAsReceived = $bundleText -match 'status==="SERVING"\)return"received"'
        }
    } | ConvertTo-Json -Depth 10
}
finally {
    if ($ordersConn.State -eq [System.Data.ConnectionState]::Open) { $ordersConn.Close() }
    if ($customersConn.State -eq [System.Data.ConnectionState]::Open) { $customersConn.Close() }
    if ($identityConn.State -eq [System.Data.ConnectionState]::Open) { $identityConn.Close() }
}
