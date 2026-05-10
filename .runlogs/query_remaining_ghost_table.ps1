$ErrorActionPreference = 'Stop'
$c = New-Object System.Data.SqlClient.SqlConnection('Server=(localdb)\MSSQLLocalDB;Database=RESTAURANT_CATALOG;Trusted_Connection=True;TrustServerCertificate=True')
$c.Open()
try {
  $cmd = $c.CreateCommand()
  $cmd.CommandText = @"
SELECT t.TableID,t.BranchID,t.TableNumber,t.QRCode,ts.StatusCode,t.CurrentOrderID
FROM DiningTables t
JOIN TableStatus ts ON ts.StatusID=t.StatusID
WHERE ts.StatusCode='OCCUPIED'
  AND t.CurrentOrderID IS NULL
ORDER BY t.TableID;
"@
  $cmd.CommandTimeout = 120
  $r = $cmd.ExecuteReader()
  while($r.Read()) { Write-Output (([string]$r['TableID'])+','+([string]$r['BranchID'])+','+([string]$r['TableNumber'])+','+([string]$r['QRCode'])+','+([string]$r['StatusCode'])+','+([string]$r['CurrentOrderID'])) }
  $r.Close()
}
finally { $c.Close() }
