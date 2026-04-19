$cs = 'Server=(localdb)\MSSQLLocalDB;Database=RESTAURANT;Trusted_Connection=True;TrustServerCertificate=True'
$cn = New-Object System.Data.SqlClient.SqlConnection $cs
$cn.Open()
$cmd = $cn.CreateCommand()
$cmd.CommandText = 'SELECT TOP 5 BillID, BillCode, OrderID, BranchIdSnapshot, BranchNameSnapshot, TableIdSnapshot, TableNameSnapshot, BillTime, EmployeeID FROM dbo.Bills ORDER BY BillID DESC'
$da = New-Object System.Data.SqlClient.SqlDataAdapter $cmd
$dt = New-Object System.Data.DataTable
[void]$da.Fill($dt)
$cn.Close()
$dt | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath 'C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main\.runlogs\debug_bill_row.json' -Encoding UTF8
Write-Host 'done'
