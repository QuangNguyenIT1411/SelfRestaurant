param(
  [Parameter(Mandatory = $true)]
  [int]$OrderId,
  [Parameter(Mandatory = $true)]
  [int]$TableId
)

$ErrorActionPreference = 'Stop'

function Invoke-DbNonQuery {
  param([string]$Database, [string]$Sql)
  $conn = New-Object System.Data.SqlClient.SqlConnection("Server=(localdb)\MSSQLLocalDB;Database=$Database;Trusted_Connection=True;TrustServerCertificate=True")
  $conn.Open()
  try {
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = $Sql
    $cmd.CommandTimeout = 60
    [void]$cmd.ExecuteNonQuery()
  }
  finally {
    $conn.Close()
  }
}

Invoke-DbNonQuery 'RESTAURANT_CUSTOMERS' @"
DELETE FROM ReadyDishNotifications WHERE OrderId = $OrderId;
DELETE FROM InboxEvents WHERE PayloadJson LIKE '%"orderId":$OrderId%';
"@

Invoke-DbNonQuery 'RESTAURANT_ORDERS' @"
DELETE FROM BusinessAuditLogs WHERE OrderId = $OrderId;
DELETE FROM SubmitCommands WHERE OrderId = $OrderId;
DELETE FROM OutboxEvents WHERE PayloadJson LIKE '%"orderId":$OrderId%';
DELETE FROM OrderItems WHERE OrderID = $OrderId;
DELETE FROM Orders WHERE OrderID = $OrderId;
"@

Invoke-DbNonQuery 'RESTAURANT_CATALOG' @"
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
WHERE t.TableID = $TableId AND t.CurrentOrderID = $OrderId;
"@

Write-Output "cleanup-ok"
