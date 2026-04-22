$ErrorActionPreference='Stop'
function Q($db,$sql){$c=New-Object System.Data.SqlClient.SqlConnection("Server=(localdb)\MSSQLLocalDB;Database=$db;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=True");$c.Open();try{$cmd=$c.CreateCommand();$cmd.CommandText=$sql;$cmd.CommandTimeout=120;$da=New-Object System.Data.SqlClient.SqlDataAdapter($cmd);$dt=New-Object System.Data.DataTable;[void]$da.Fill($dt);$dt}finally{$c.Close()}}
$orders = Q 'RESTAURANT_ORDERS' "SELECT OrderID, OrderCode, Note, CustomerID, TableID, StatusID, IsActive, CONVERT(varchar(19), OrderTime, 120) AS OrderTime, DiningSessionCode FROM Orders WHERE OrderID IN (287,288,289,290,291) ORDER BY OrderID;"
$items = Q 'RESTAURANT_ORDERS' "SELECT ItemID, OrderID, DishID, Quantity, Note, LineTotal FROM OrderItems WHERE OrderID IN (287,288,289,290,291) ORDER BY ItemID;"
$bills = Q 'RESTAURANT_BILLING' "SELECT BillID, BillCode, OrderID, OrderCodeSnapshot, PaymentMethod, TotalAmount, CustomerID, CONVERT(varchar(19), BillTime, 120) AS BillTime FROM Bills WHERE OrderID IN (287,288,289,290,291) ORDER BY BillID;"
$checkout = Q 'RESTAURANT_BILLING' "SELECT CheckoutCommandId, OrderId, BillId, BillCode, Status, IdempotencyKey, CONVERT(varchar(19), CreatedAtUtc, 120) AS CreatedAtUtc FROM CheckoutCommands WHERE OrderId IN (287,288,289,290,291) ORDER BY CheckoutCommandId;"
Write-Output '=== Orders ==='; $orders | ConvertTo-Csv -NoTypeInformation | Write-Output
Write-Output '=== OrderItems ==='; $items | ConvertTo-Csv -NoTypeInformation | Write-Output
Write-Output '=== Bills ==='; $bills | ConvertTo-Csv -NoTypeInformation | Write-Output
Write-Output '=== Checkout ==='; $checkout | ConvertTo-Csv -NoTypeInformation | Write-Output
