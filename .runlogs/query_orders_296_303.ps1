$ErrorActionPreference = 'Stop'
$c = New-Object System.Data.SqlClient.SqlConnection('Server=(localdb)\MSSQLLocalDB;Database=RESTAURANT_ORDERS;Trusted_Connection=True;TrustServerCertificate=True')
$c.Open()
try {
  $cmd = $c.CreateCommand()
  $cmd.CommandText = 'SELECT o.OrderID,o.OrderCode,o.TableID,o.CustomerID,o.IsActive,os.StatusCode,CONVERT(varchar(19),o.OrderTime,120) AS OrderTime,CONVERT(varchar(19),o.CompletedTime,120) AS CompletedTime FROM Orders o JOIN OrderStatus os ON os.StatusID=o.StatusID WHERE o.OrderID IN (296,297,298,299,301,302,303) ORDER BY o.OrderID'
  $cmd.CommandTimeout = 120
  $r = $cmd.ExecuteReader()
  while ($r.Read()) {
    Write-Output (([string]$r['OrderID']) + ',' + ([string]$r['OrderCode']) + ',' + ([string]$r['TableID']) + ',' + ([string]$r['CustomerID']) + ',' + ([string]$r['IsActive']) + ',' + ([string]$r['StatusCode']) + ',' + ([string]$r['OrderTime']) + ',' + ([string]$r['CompletedTime']))
  }
  $r.Close()
}
finally { $c.Close() }
