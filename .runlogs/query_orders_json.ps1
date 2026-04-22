$ErrorActionPreference='Stop'
function Q($db,$sql){$c=New-Object System.Data.SqlClient.SqlConnection("Server=(localdb)\MSSQLLocalDB;Database=$db;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=True");$c.Open();try{$cmd=$c.CreateCommand();$cmd.CommandText=$sql;$cmd.CommandTimeout=120;$da=New-Object System.Data.SqlClient.SqlDataAdapter($cmd);$dt=New-Object System.Data.DataTable;[void]$da.Fill($dt);$dt}finally{$c.Close()}}
$orders = Q 'RESTAURANT_ORDERS' "SELECT * FROM Orders WHERE OrderID IN (287,288,289,290,291) ORDER BY OrderID;"
$items = Q 'RESTAURANT_ORDERS' "SELECT * FROM OrderItems WHERE OrderID IN (287,288,289,290,291) ORDER BY ItemID;"
$bills = Q 'RESTAURANT_BILLING' "SELECT * FROM Bills WHERE OrderID IN (287,288,289,290,291) ORDER BY BillID;"
$checkout = Q 'RESTAURANT_BILLING' "SELECT * FROM CheckoutCommands WHERE OrderId IN (287,288,289,290,291) ORDER BY CheckoutCommandId;"
[pscustomobject]@{ Orders = $orders; OrderItems = $items; Bills = $bills; Checkout = $checkout } | ConvertTo-Json -Depth 6
