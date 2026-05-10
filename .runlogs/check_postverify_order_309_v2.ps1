$ErrorActionPreference='Stop'
function Conn($db){$c=New-Object System.Data.SqlClient.SqlConnection("Server=(localdb)\MSSQLLocalDB;Database=$db;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=True");$c.Open();$c}
function TableToObjects($dt){ @($dt.Rows | ForEach-Object { $o=[ordered]@{}; foreach($col in $dt.Columns){ $o[$col.ColumnName]=$_.Item($col.ColumnName) }; [pscustomobject]$o }) }
function Query($conn,$sql){$cmd=$conn.CreateCommand();$cmd.CommandText=$sql;$cmd.CommandTimeout=120;$da=New-Object System.Data.SqlClient.SqlDataAdapter($cmd);$dt=New-Object System.Data.DataTable;[void]$da.Fill($dt); $dt}
$orders=Conn 'RESTAURANT_ORDERS'; $catalog=Conn 'RESTAURANT_CATALOG'
try {
  $o=Query $orders @"
SELECT o.OrderID,o.OrderCode,o.TableID,os.StatusCode,ISNULL(o.IsActive,0) AS IsActive,
       (SELECT COUNT(*) FROM OrderItems oi WHERE oi.OrderID=o.OrderID) AS ItemCount,
       (SELECT COUNT(*) FROM [RESTAURANT_BILLING].dbo.Bills b WHERE b.OrderID=o.OrderID) AS BillCount
FROM Orders o JOIN OrderStatus os ON os.StatusID=o.StatusID
WHERE o.OrderID=309;
"@
  $t=Query $catalog "SELECT TableID, CurrentOrderID, StatusID FROM DiningTables WHERE TableID=39;"
  [pscustomobject]@{order=(TableToObjects $o); table=(TableToObjects $t)} | ConvertTo-Json -Depth 5
} finally {$orders.Close(); $catalog.Close()}
