Add-Type -AssemblyName System.Data
$server='(localdb)\MSSQLLocalDB'
$dbs=@('RESTAURANT','RESTAURANT_CATALOG','RESTAURANT_ORDERS','RESTAURANT_CUSTOMERS','RESTAURANT_IDENTITY','RESTAURANT_BILLING')
$conn = New-Object System.Data.SqlClient.SqlConnection("Server=$server;Database=master;Trusted_Connection=True;TrustServerCertificate=True;")
$conn.Open()
$cmd=$conn.CreateCommand()
$cmd.CommandText="SELECT name FROM sys.databases WHERE name IN ('RESTAURANT','RESTAURANT_CATALOG','RESTAURANT_ORDERS','RESTAURANT_CUSTOMERS','RESTAURANT_IDENTITY','RESTAURANT_BILLING') ORDER BY name"
$r=$cmd.ExecuteReader()
while($r.Read()){ Write-Output ($r.GetString(0)) }
$r.Close()
$conn.Close()
foreach($db in $dbs[1..5]){
  $c = New-Object System.Data.SqlClient.SqlConnection("Server=$server;Database=$db;Trusted_Connection=True;TrustServerCertificate=True;")
  $c.Open()
  $cmd=$c.CreateCommand()
  $cmd.CommandText='SELECT COUNT(*) FROM sys.synonyms'
  $count=$cmd.ExecuteScalar()
  $c.Close()
  Write-Output ($db + '=' + $count)
}
