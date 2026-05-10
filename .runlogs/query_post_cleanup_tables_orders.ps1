$ErrorActionPreference = 'Stop'
function Conn($db){$c=New-Object System.Data.SqlClient.SqlConnection("Server=(localdb)\MSSQLLocalDB;Database=$db;Trusted_Connection=True;TrustServerCertificate=True");$c.Open();$c}
$catalog=Conn 'RESTAURANT_CATALOG'; $orders=Conn 'RESTAURANT_ORDERS'; $billing=Conn 'RESTAURANT_BILLING'
try {
  $queries = @(
    @{ db=$catalog; sql="SELECT COUNT(*) FROM DiningTables t JOIN TableStatus ts ON ts.StatusID=t.StatusID WHERE ts.StatusCode='OCCUPIED' AND t.CurrentOrderID IS NULL"; label='ghost_table_count' },
    @{ db=$orders; sql="SELECT COUNT(*) FROM Orders WHERE OrderID IN (296,297,298,299,301,302,303)"; label='removed_orders_left' },
    @{ db=$billing; sql="SELECT COUNT(*) FROM Bills WHERE BillID=138 OR OrderID IN (296,297,298,299,301,302,303)"; label='removed_bills_left' },
    @{ db=$catalog; sql="SELECT COUNT(*) FROM Ingredients WHERE IngredientID IN (54,61,69)"; label='removed_ingredients_left' }
  )
  foreach($q in $queries){ $cmd=$q.db.CreateCommand(); $cmd.CommandText=$q.sql; Write-Output ($q.label + '=' + [string]$cmd.ExecuteScalar()) }
}
finally { $catalog.Close(); $orders.Close(); $billing.Close() }
