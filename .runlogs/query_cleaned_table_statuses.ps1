$ErrorActionPreference = 'Stop'
$c = New-Object System.Data.SqlClient.SqlConnection('Server=(localdb)\MSSQLLocalDB;Database=RESTAURANT_CATALOG;Trusted_Connection=True;TrustServerCertificate=True')
$c.Open()
try {
  $cmd = $c.CreateCommand()
  $cmd.CommandText = 'SELECT t.TableID,t.BranchID,t.TableNumber,ts.StatusCode,t.CurrentOrderID FROM DiningTables t JOIN TableStatus ts ON ts.StatusID=t.StatusID WHERE t.TableID IN (6,21,22,23,24,38) ORDER BY t.TableID'
  $cmd.CommandTimeout = 120
  $r = $cmd.ExecuteReader()
  while($r.Read()) { Write-Output (([string]$r['TableID'])+','+([string]$r['BranchID'])+','+([string]$r['TableNumber'])+','+([string]$r['StatusCode'])+','+([string]$r['CurrentOrderID'])) }
  $r.Close()
}
finally { $c.Close() }
