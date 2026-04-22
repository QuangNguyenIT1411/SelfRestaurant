$ErrorActionPreference='Stop'
function Q($db,$sql){$c=New-Object System.Data.SqlClient.SqlConnection("Server=(localdb)\MSSQLLocalDB;Database=$db;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=True");$c.Open();try{$cmd=$c.CreateCommand();$cmd.CommandText=$sql;$cmd.CommandTimeout=120;$da=New-Object System.Data.SqlClient.SqlDataAdapter($cmd);$dt=New-Object System.Data.DataTable;[void]$da.Fill($dt);$dt}finally{$c.Close()}}
Write-Output '=== Billing auxiliary rows ==='
Q 'RESTAURANT_BILLING' @"
SELECT * FROM OrderContextSnapshots WHERE OrderId IN (287,288,289,290,291);
SELECT * FROM CheckoutCommands WHERE OrderId IN (287,288,289,290,291);
"@ | Format-Table -AutoSize | Out-String -Width 240 | Write-Output
Write-Output '=== Catalog table state for recent test orders ==='
Q 'RESTAURANT_CATALOG' @"
SELECT t.TableID,t.CurrentOrderID,t.StatusID,s.StatusCode,s.StatusName,t.IsActive
FROM DiningTables t JOIN TableStatus s ON s.StatusID=t.StatusID
WHERE t.TableID IN (1,2,3,37);
"@ | Format-Table -AutoSize | Out-String -Width 240 | Write-Output
Write-Output '=== Identity refs for candidate customers ==='
Q 'RESTAURANT_IDENTITY' @"
SELECT c.CustomerID,c.Name,c.Username,c.PhoneNumber,c.Email,lc.CardNumber
FROM Customers c LEFT JOIN LoyaltyCards lc ON lc.CustomerID=c.CustomerID
WHERE c.CustomerID IN (1231,2613,2620);
SELECT * FROM PasswordResetTokens WHERE CustomerID IN (1231,2613,2620);
"@ | Format-Table -AutoSize | Out-String -Width 240 | Write-Output
