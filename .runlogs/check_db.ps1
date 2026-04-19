$cn='Server=(localdb)\MSSQLLocalDB;Database=master;Trusted_Connection=True;TrustServerCertificate=True;'
$c=New-Object System.Data.SqlClient.SqlConnection $cn
$c.Open()
$cmd=$c.CreateCommand()
$cmd.CommandText="SELECT name FROM sys.databases WHERE name IN ('RESTAURANT','RESTAURANT_ORDERS') ORDER BY name"
$r=$cmd.ExecuteReader()
while($r.Read()){ Write-Output $r.GetString(0) }
$r.Close()
$c.Dispose()

$cn2='Server=(localdb)\MSSQLLocalDB;Database=RESTAURANT_ORDERS;Trusted_Connection=True;TrustServerCertificate=True;'
$c2=New-Object System.Data.SqlClient.SqlConnection $cn2
$c2.Open()
$cmd2=$c2.CreateCommand()
$cmd2.CommandText="SELECT name, type_desc FROM sys.objects WHERE name IN ('Orders','OrderItems','OrderStatus') ORDER BY name"
$r2=$cmd2.ExecuteReader()
while($r2.Read()){ Write-Output ($r2.GetString(0) + ':' + $r2.GetString(1)) }
$r2.Close()
$c2.Dispose()
