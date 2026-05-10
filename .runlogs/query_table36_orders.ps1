$ErrorActionPreference = 'Stop'
$c = New-Object System.Data.SqlClient.SqlConnection('Server=(localdb)\MSSQLLocalDB;Database=RESTAURANT_ORDERS;Trusted_Connection=True;TrustServerCertificate=True')
$c.Open()
try {
  $cmd = $c.CreateCommand()
  $cmd.CommandText = @"
SELECT o.OrderID,o.OrderCode,o.IsActive,os.StatusCode,CONVERT(varchar(19),o.OrderTime,120) AS OrderTime
FROM Orders o
JOIN OrderStatus os ON os.StatusID=o.StatusID
WHERE o.TableID=36
ORDER BY o.OrderID DESC;
"@
  $cmd.CommandTimeout = 120
  $r = $cmd.ExecuteReader()
  while($r.Read()) { Write-Output (([string]$r['OrderID'])+','+([string]$r['OrderCode'])+','+([string]$r['IsActive'])+','+([string]$r['StatusCode'])+','+([string]$r['OrderTime'])) }
  $r.Close()
}
finally { $c.Close() }
