$cn = 'Server=(localdb)\MSSQLLocalDB;Database=RESTAURANT_CATALOG;Trusted_Connection=True;TrustServerCertificate=True;'
$conn = New-Object System.Data.SqlClient.SqlConnection $cn
$conn.Open()
$cmd = $conn.CreateCommand()
$cmd.CommandText = 'SELECT TOP 30 TableID, BranchID, TableNumber, QRCode FROM TableNumbers ORDER BY BranchID, TableNumber'
$r = $cmd.ExecuteReader()
$rows = @()
while ($r.Read()) {
  $rows += [pscustomobject]@{ TableID = $r.GetInt32(0); BranchID = $r.GetInt32(1); TableNumber = $r.GetInt64(2); QRCode = $(if ($r.IsDBNull(3)) { '' } else { $r.GetString(3) }) }
}
$conn.Close()
$rows | Format-Table -AutoSize | Out-String -Width 220
