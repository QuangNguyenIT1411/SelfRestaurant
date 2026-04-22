$ErrorActionPreference='Stop'
$conn = New-Object System.Data.SqlClient.SqlConnection('Server=(localdb)\MSSQLLocalDB;Database=RESTAURANT_CUSTOMERS;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=True')
$conn.Open()
try {
  $cmd = $conn.CreateCommand()
  $cmd.CommandText = "SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE='BASE TABLE' ORDER BY TABLE_NAME"
  $da = New-Object System.Data.SqlClient.SqlDataAdapter($cmd)
  $dt = New-Object System.Data.DataTable
  [void]$da.Fill($dt)
  $tables = $dt.Rows | ForEach-Object { $_.TABLE_NAME }
  Write-Output '=== Tables ==='
  $tables | ForEach-Object { $_ }
  foreach ($table in $tables) {
    try {
      $cmd2 = $conn.CreateCommand(); $cmd2.CommandText = "SELECT TOP 5 * FROM dbo.[$table]"; $cmd2.CommandTimeout = 30
      $da2 = New-Object System.Data.SqlClient.SqlDataAdapter($cmd2)
      $dt2 = New-Object System.Data.DataTable
      [void]$da2.Fill($dt2)
      Write-Output "=== $table sample ==="
      if ($dt2.Rows.Count -eq 0) { Write-Output '<empty>'; continue }
      $dt2 | ConvertTo-Csv -NoTypeInformation | Write-Output
    } catch { Write-Output "=== $table sample ==="; Write-Output "<query failed> $($_.Exception.Message)" }
  }
} finally { $conn.Close() }
