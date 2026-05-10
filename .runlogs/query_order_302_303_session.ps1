$ErrorActionPreference = 'Stop'
$c = New-Object System.Data.SqlClient.SqlConnection('Server=(localdb)\MSSQLLocalDB;Database=RESTAURANT_ORDERS;Trusted_Connection=True;TrustServerCertificate=True')
$c.Open()
try {
  $cmd = $c.CreateCommand()
  $cmd.CommandText = 'SELECT OrderID,OrderCode,TableID,DiningSessionCode,CustomerID,OrderTime,CompletedTime,IsActive FROM Orders WHERE OrderID IN (302,303) ORDER BY OrderID'
  $cmd.CommandTimeout = 120
  $r = $cmd.ExecuteReader()
  while($r.Read()) { Write-Output (([string]$r['OrderID'])+','+([string]$r['OrderCode'])+','+([string]$r['TableID'])+','+([string]$r['DiningSessionCode'])+','+([string]$r['CustomerID'])+','+([string]$r['OrderTime'])+','+([string]$r['CompletedTime'])+','+([string]$r['IsActive'])) }
  $r.Close()
}
finally { $c.Close() }
