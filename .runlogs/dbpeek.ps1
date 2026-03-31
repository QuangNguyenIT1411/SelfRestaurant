$ErrorActionPreference='Stop'
$conn=New-Object System.Data.SqlClient.SqlConnection('Server=(localdb)\MSSQLLocalDB;Database=RESTAURANT;Trusted_Connection=True;TrustServerCertificate=True;')
$conn.Open()
$cmd=$conn.CreateCommand()
$cmd.CommandText="SELECT TOP 1 Username FROM Customers ORDER BY CustomerID DESC"
$u=$cmd.ExecuteScalar()
$cmd2=$conn.CreateCommand()
$cmd2.CommandText="SELECT TOP 1 QRCode FROM DiningTables WHERE QRCode IS NOT NULL AND LTRIM(RTRIM(QRCode))<>'' ORDER BY TableID DESC"
$qr=$cmd2.ExecuteScalar()
$conn.Close()
Write-Output "latestUser=$u"
Write-Output "sampleQr=$qr"
