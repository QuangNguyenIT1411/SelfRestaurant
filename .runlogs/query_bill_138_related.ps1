$ErrorActionPreference = 'Stop'
$c = New-Object System.Data.SqlClient.SqlConnection('Server=(localdb)\MSSQLLocalDB;Database=RESTAURANT_BILLING;Trusted_Connection=True;TrustServerCertificate=True')
$c.Open()
try {
  $queries = @(
    'SELECT COUNT(*) AS Cnt FROM BusinessAuditLogs WHERE BillId = 138 OR OrderId = 298',
    'SELECT COUNT(*) AS Cnt FROM CheckoutCommands WHERE BillId = 138 OR OrderId = 298',
    'SELECT COUNT(*) AS Cnt FROM OrderContextSnapshots WHERE OrderId = 298',
    'SELECT COUNT(*) AS Cnt FROM OutboxEvents WHERE PayloadJson LIKE ''%"orderId":298%'' OR PayloadJson LIKE ''%"billId":138%'''
  )
  foreach ($sql in $queries) {
    $cmd = $c.CreateCommand(); $cmd.CommandText = $sql; $cmd.CommandTimeout = 120
    Write-Output ($cmd.ExecuteScalar())
  }
}
finally { $c.Close() }
