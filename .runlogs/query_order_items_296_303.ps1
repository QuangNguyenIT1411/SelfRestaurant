$ErrorActionPreference = 'Stop'
$c = New-Object System.Data.SqlClient.SqlConnection('Server=(localdb)\MSSQLLocalDB;Database=RESTAURANT_ORDERS;Trusted_Connection=True;TrustServerCertificate=True')
$c.Open()
try {
  $cmd = $c.CreateCommand()
  $cmd.CommandText = 'SELECT ItemID,OrderID,DishID,Quantity,StatusCode,ISNULL(Note,'''') AS NoteText FROM OrderItems WHERE OrderID IN (296,297,298,299,301,302,303) ORDER BY OrderID,ItemID'
  $cmd.CommandTimeout = 120
  $r = $cmd.ExecuteReader()
  while ($r.Read()) {
    Write-Output (([string]$r['ItemID']) + ',' + ([string]$r['OrderID']) + ',' + ([string]$r['DishID']) + ',' + ([string]$r['Quantity']) + ',' + ([string]$r['StatusCode']) + ',' + ([string]$r['NoteText']))
  }
  $r.Close()
}
finally { $c.Close() }
