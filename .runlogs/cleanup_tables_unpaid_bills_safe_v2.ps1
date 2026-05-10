$ErrorActionPreference='Stop'
function Conn($db){$c=New-Object System.Data.SqlClient.SqlConnection("Server=(localdb)\MSSQLLocalDB;Database=$db;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=True");$c.Open();$c}
function Query($conn,$sql){$cmd=$conn.CreateCommand();$cmd.CommandText=$sql;$cmd.CommandTimeout=120;$da=New-Object System.Data.SqlClient.SqlDataAdapter($cmd);$dt=New-Object System.Data.DataTable;[void]$da.Fill($dt);$dt}
function NonQuery($conn,$tx,$sql){$cmd=$conn.CreateCommand(); if($tx){$cmd.Transaction=$tx}; $cmd.CommandText=$sql; $cmd.CommandTimeout=120; $cmd.ExecuteNonQuery() | Out-Null}
$catalog=Conn 'RESTAURANT_CATALOG'
$billing=Conn 'RESTAURANT_BILLING'
try {
  $ghostSql = @"
SELECT t.TableID, t.BranchID, t.QRCode, ts.StatusCode
FROM DiningTables t
JOIN TableStatus ts ON ts.StatusID=t.StatusID
WHERE ISNULL(t.IsActive,1)=1
  AND ts.StatusCode='OCCUPIED'
  AND t.CurrentOrderID IS NULL
  AND NOT EXISTS (
      SELECT 1
      FROM [RESTAURANT_ORDERS].dbo.Orders o
      JOIN [RESTAURANT_ORDERS].dbo.OrderStatus os ON os.StatusID=o.StatusID
      WHERE o.TableID=t.TableID
        AND ISNULL(o.IsActive,0)=1
        AND os.StatusCode IN ('PENDING','CONFIRMED','PREPARING','READY','SERVING')
  )
ORDER BY t.BranchID,t.TableID;
"@
  $testTableSql = @"
SELECT t.TableID,t.BranchID,t.QRCode,ts.StatusCode,t.CurrentOrderID
FROM DiningTables t
LEFT JOIN TableStatus ts ON ts.StatusID=t.StatusID
WHERE t.QRCode LIKE 'AUTO-%'
   OR UPPER(ISNULL(t.QRCode,'')) LIKE 'CODEX-TB-TEST%'
   OR UPPER(ISNULL(t.QRCode,'')) LIKE '%TEST%'
ORDER BY t.TableID;
"@
  $inactiveBillSql = "SELECT BillID,OrderID,BillCode,IsActive FROM Bills WHERE ISNULL(IsActive,1)=0 ORDER BY BillID;"
  $nonCompletedSql = @"
SELECT CheckoutCommandId,OrderId,BillId,BillCode,Status,Error
FROM CheckoutCommands
WHERE Status <> 'COMPLETED'
ORDER BY CheckoutCommandId;
"@

  $beforeGhost = Query $catalog $ghostSql
  $testTables = Query $catalog $testTableSql
  $inactiveBills = Query $billing $inactiveBillSql
  $nonCompleted = Query $billing $nonCompletedSql

  $catalogTx = $catalog.BeginTransaction()
  $billingTx = $billing.BeginTransaction()
  try {
    NonQuery $catalog $catalogTx @"
DECLARE @availableStatusId int = (SELECT TOP 1 StatusID FROM TableStatus WHERE StatusCode='AVAILABLE');
UPDATE t
SET StatusID=@availableStatusId,
    CurrentOrderID=NULL,
    UpdatedAt=GETDATE()
FROM DiningTables t
JOIN TableStatus ts ON ts.StatusID=t.StatusID
WHERE ISNULL(t.IsActive,1)=1
  AND ts.StatusCode='OCCUPIED'
  AND t.CurrentOrderID IS NULL
  AND NOT EXISTS (
      SELECT 1
      FROM [RESTAURANT_ORDERS].dbo.Orders o
      JOIN [RESTAURANT_ORDERS].dbo.OrderStatus os ON os.StatusID=o.StatusID
      WHERE o.TableID=t.TableID
        AND ISNULL(o.IsActive,0)=1
        AND os.StatusCode IN ('PENDING','CONFIRMED','PREPARING','READY','SERVING')
  );
"@
    if($testTables.Rows.Count -gt 0){
      NonQuery $catalog $catalogTx @"
DECLARE @TestTables TABLE (TableID int PRIMARY KEY);
INSERT INTO @TestTables(TableID)
SELECT TableID FROM DiningTables
WHERE QRCode LIKE 'AUTO-%'
   OR UPPER(ISNULL(QRCode,'')) LIKE 'CODEX-TB-TEST%'
   OR UPPER(ISNULL(QRCode,'')) LIKE '%TEST%';
DELETE FROM BusinessAuditLogs WHERE TableId IN (SELECT TableID FROM @TestTables);
DELETE FROM DiningTables
WHERE TableID IN (SELECT TableID FROM @TestTables)
  AND NOT EXISTS (SELECT 1 FROM [RESTAURANT_ORDERS].dbo.Orders o WHERE o.TableID = DiningTables.TableID);
"@
    }
    if($inactiveBills.Rows.Count -gt 0){
      NonQuery $billing $billingTx @"
DECLARE @DeadBills TABLE (BillID int PRIMARY KEY);
INSERT INTO @DeadBills(BillID) SELECT BillID FROM Bills WHERE ISNULL(IsActive,1)=0;
DELETE FROM BusinessAuditLogs WHERE BillId IN (SELECT BillID FROM @DeadBills);
DELETE FROM Bills WHERE BillID IN (SELECT BillID FROM @DeadBills);
"@
    }
    if($nonCompleted.Rows.Count -gt 0){
      NonQuery $billing $billingTx "DELETE FROM CheckoutCommands WHERE Status <> 'COMPLETED';"
    }
    $catalogTx.Commit(); $billingTx.Commit()
  } catch {
    $catalogTx.Rollback(); $billingTx.Rollback(); throw
  }

  $afterGhost = Query $catalog $ghostSql
  $afterInactiveBills = Query $billing $inactiveBillSql
  $afterNonCompleted = Query $billing $nonCompletedSql

  [pscustomobject]@{
    ghostTablesBefore = @($beforeGhost | Select-Object TableID,BranchID,QRCode,StatusCode)
    testTablesFound = @($testTables | Select-Object TableID,BranchID,QRCode,StatusCode,CurrentOrderID)
    inactiveBillsFound = @($inactiveBills | Select-Object BillID,OrderID,BillCode,IsActive)
    nonCompletedCheckoutFound = @($nonCompleted | Select-Object CheckoutCommandId,OrderId,BillId,BillCode,Status,Error)
    ghostTablesAfter = @($afterGhost | Select-Object TableID,BranchID,QRCode,StatusCode)
    inactiveBillsAfter = @($afterInactiveBills | Select-Object BillID,OrderID,BillCode,IsActive)
    nonCompletedCheckoutAfter = @($afterNonCompleted | Select-Object CheckoutCommandId,OrderId,BillId,BillCode,Status,Error)
  } | ConvertTo-Json -Depth 6
}
finally { $catalog.Close(); $billing.Close() }
