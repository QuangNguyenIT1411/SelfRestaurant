$ErrorActionPreference = 'Stop'
$c = New-Object System.Data.SqlClient.SqlConnection('Server=(localdb)\MSSQLLocalDB;Database=RESTAURANT_BILLING;Trusted_Connection=True;TrustServerCertificate=True')
$c.Open()
try {
  $cmd = $c.CreateCommand()
  $cmd.CommandText = 'SELECT BillID,OrderID,BillCode,IsActive,TotalAmount,PaymentMethod FROM Bills WHERE OrderID IN (296,297,298,299,301,302,303) ORDER BY BillID'
  $cmd.CommandTimeout = 120
  $r = $cmd.ExecuteReader()
  while ($r.Read()) {
    Write-Output (([string]$r['BillID']) + ',' + ([string]$r['OrderID']) + ',' + ([string]$r['BillCode']) + ',' + ([string]$r['IsActive']) + ',' + ([string]$r['TotalAmount']) + ',' + ([string]$r['PaymentMethod']))
  }
  $r.Close()
}
finally { $c.Close() }
