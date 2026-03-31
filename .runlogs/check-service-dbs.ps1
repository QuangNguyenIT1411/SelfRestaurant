$sqlcmd = 'C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\SQLCMD.EXE'
$server = '(localdb)\MSSQLLocalDB'
& $sqlcmd -S $server -E -W -h -1 -Q "SET NOCOUNT ON; SELECT name FROM sys.databases WHERE name IN ('RESTAURANT','RESTAURANT_CATALOG','RESTAURANT_ORDERS','RESTAURANT_CUSTOMERS','RESTAURANT_IDENTITY','RESTAURANT_BILLING') ORDER BY name;"
Write-Host '---'
foreach($db in 'RESTAURANT_CATALOG','RESTAURANT_ORDERS','RESTAURANT_CUSTOMERS','RESTAURANT_IDENTITY','RESTAURANT_BILLING'){
  $count = & $sqlcmd -S $server -E -d $db -W -h -1 -Q "SET NOCOUNT ON; SELECT COUNT(*) FROM sys.synonyms;"
  Write-Host "$db => $count synonyms"
}
