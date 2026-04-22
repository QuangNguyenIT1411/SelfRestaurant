$ErrorActionPreference='Stop'
function Q($db,$sql){$c=New-Object System.Data.SqlClient.SqlConnection("Server=(localdb)\MSSQLLocalDB;Database=$db;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=True");$c.Open();try{$cmd=$c.CreateCommand();$cmd.CommandText=$sql;$cmd.CommandTimeout=120;$da=New-Object System.Data.SqlClient.SqlDataAdapter($cmd);$dt=New-Object System.Data.DataTable;[void]$da.Fill($dt);$dt}finally{$c.Close()}}
Write-Output '=== Candidate customers ==='
Q 'RESTAURANT_IDENTITY' @"
SELECT CustomerID, Name, Username, PhoneNumber, Email, ISNULL(IsActive,0) AS IsActive
FROM Customers
WHERE CustomerID IN (1231,2613,2620)
ORDER BY CustomerID;
"@ | Format-Table -AutoSize | Out-String -Width 240 | Write-Output
Write-Output '=== Loyalty cards ==='
Q 'RESTAURANT_IDENTITY' @"
SELECT * FROM LoyaltyCards WHERE CustomerID IN (1231,2613,2620);
"@ | Format-Table -AutoSize | Out-String -Width 240 | Write-Output
Write-Output '=== Password reset tokens ==='
Q 'RESTAURANT_IDENTITY' @"
SELECT * FROM PasswordResetTokens WHERE CustomerID IN (1231,2613,2620);
"@ | Format-Table -AutoSize | Out-String -Width 240 | Write-Output
Write-Output '=== Orders refs ==='
Q 'RESTAURANT_ORDERS' @"
SELECT OrderID, CustomerID, OrderCode, Note, StatusID FROM Orders WHERE CustomerID IN (1231,2613,2620) ORDER BY OrderID;
"@ | Format-Table -AutoSize | Out-String -Width 240 | Write-Output
Write-Output '=== Bills refs ==='
Q 'RESTAURANT_BILLING' @"
SELECT BillID, CustomerID, BillCode, OrderID, TotalAmount FROM Bills WHERE CustomerID IN (1231,2613,2620) ORDER BY BillID;
"@ | Format-Table -AutoSize | Out-String -Width 240 | Write-Output
