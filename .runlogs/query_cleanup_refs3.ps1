$ErrorActionPreference = 'Stop'
function Query($db, $sql) {
  $conn = New-Object System.Data.SqlClient.SqlConnection("Server=(localdb)\MSSQLLocalDB;Database=$db;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=True")
  $conn.Open()
  try {
    $cmd = $conn.CreateCommand(); $cmd.CommandText = $sql; $cmd.CommandTimeout = 120
    $da = New-Object System.Data.SqlClient.SqlDataAdapter($cmd)
    $dt = New-Object System.Data.DataTable
    [void]$da.Fill($dt)
    return $dt
  } finally { $conn.Close() }
}
Write-Output '=== Orders refs to auto tables ==='
Query 'RESTAURANT_ORDERS' @"
SELECT TableID, COUNT(*) AS OrderRefs
FROM Orders
WHERE TableID IN (48,49,50,51,52,53,54,55,1055,1056,1057,1058,1059,1060,1061,1062,1063,1064,1065,1066,1067,1068,1069)
GROUP BY TableID
ORDER BY TableID;
"@ | Format-Table -AutoSize | Out-String -Width 240 | Write-Output
Write-Output '=== Recent orders detail ==='
Query 'RESTAURANT_ORDERS' @"
SELECT o.OrderID, o.OrderCode, o.Note, o.CustomerID, o.TableID, o.StatusID, o.IsActive, o.OrderTime,
       COUNT(oi.ItemID) AS ItemCount,
       SUM(CASE WHEN oi.ItemID IS NULL THEN 0 ELSE oi.LineTotal END) AS ItemTotal
FROM Orders o
LEFT JOIN OrderItems oi ON oi.OrderID = o.OrderID
WHERE o.OrderID >= 280
GROUP BY o.OrderID, o.OrderCode, o.Note, o.CustomerID, o.TableID, o.StatusID, o.IsActive, o.OrderTime
ORDER BY o.OrderID;
"@ | Format-Table -AutoSize | Out-String -Width 240 | Write-Output
Write-Output '=== Recent bills detail ==='
Query 'RESTAURANT_BILLING' @"
SELECT b.BillID, b.BillCode, b.OrderID, b.OrderCodeSnapshot, b.PaymentMethod, b.TotalAmount, b.CustomerID, b.BillTime,
       cc.CheckoutCommandId, cc.Status, cc.CompletedAtUtc
FROM Bills b
LEFT JOIN CheckoutCommands cc ON cc.BillId = b.BillID
WHERE b.BillID >= 130
ORDER BY b.BillID;
"@ | Format-Table -AutoSize | Out-String -Width 240 | Write-Output
