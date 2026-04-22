$ErrorActionPreference='Stop'
function Q($db,$sql){$c=New-Object System.Data.SqlClient.SqlConnection("Server=(localdb)\MSSQLLocalDB;Database=$db;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=True");$c.Open();try{$cmd=$c.CreateCommand();$cmd.CommandText=$sql;$cmd.CommandTimeout=120;$da=New-Object System.Data.SqlClient.SqlDataAdapter($cmd);$dt=New-Object System.Data.DataTable;[void]$da.Fill($dt);$dt}finally{$c.Close()}}
Write-Output '=== Orders submit/business/outbox ==='
Q 'RESTAURANT_ORDERS' @"
SELECT SubmitCommandId, OrderId, IdempotencyKey, Status FROM SubmitCommands WHERE OrderId IN (287,288,289,290,291);
SELECT BusinessAuditLogId, ActionType, EntityType, EntityId, OrderId, TableId FROM BusinessAuditLogs WHERE OrderId IN (287,288,289,290,291) ORDER BY BusinessAuditLogId;
SELECT OutboxEventId, EventName, Status, CorrelationId FROM OutboxEvents WHERE PayloadJson LIKE '%\"orderId\":289%' OR PayloadJson LIKE '%\"orderId\":290%' OR PayloadJson LIKE '%\"orderId\":291%' OR PayloadJson LIKE '%\"orderId\":287%' OR PayloadJson LIKE '%\"orderId\":288%';
"@ | Format-Table -AutoSize | Out-String -Width 240 | Write-Output
Write-Output '=== Billing audit/outbox ==='
Q 'RESTAURANT_BILLING' @"
SELECT BusinessAuditLogId, ActionType, EntityType, EntityId, OrderId, BillId FROM BusinessAuditLogs WHERE OrderId IN (287,288,289,290,291) OR BillId IN (137) ORDER BY BusinessAuditLogId;
SELECT OutboxEventId, EventName, Status, CorrelationId FROM OutboxEvents WHERE PayloadJson LIKE '%\"orderId\":291%' OR PayloadJson LIKE '%\"billId\":137%';
"@ | Format-Table -AutoSize | Out-String -Width 240 | Write-Output
