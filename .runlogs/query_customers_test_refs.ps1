$ErrorActionPreference='Stop'
function Q($sql){$c=New-Object System.Data.SqlClient.SqlConnection('Server=(localdb)\MSSQLLocalDB;Database=RESTAURANT_CUSTOMERS;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=True');$c.Open();try{$cmd=$c.CreateCommand();$cmd.CommandText=$sql;$cmd.CommandTimeout=120;$da=New-Object System.Data.SqlClient.SqlDataAdapter($cmd);$dt=New-Object System.Data.DataTable;[void]$da.Fill($dt);$dt}finally{$c.Close()}}
Write-Output '=== Customer db refs for candidate orders ==='
Q @"
SELECT * FROM ReadyDishNotifications WHERE OrderId IN (287,288,289,290,291) ORDER BY ReadyDishNotificationId;
SELECT * FROM InboxEvents WHERE PayloadJson LIKE '%\"orderId\":287%' OR PayloadJson LIKE '%\"orderId\":288%' OR PayloadJson LIKE '%\"orderId\":289%' OR PayloadJson LIKE '%\"orderId\":290%' OR PayloadJson LIKE '%\"orderId\":291%';
"@ | ConvertTo-Csv -NoTypeInformation | Write-Output
