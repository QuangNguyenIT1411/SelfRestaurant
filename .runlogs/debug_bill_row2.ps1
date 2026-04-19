$cs = 'Server=(localdb)\MSSQLLocalDB;Database=RESTAURANT;Trusted_Connection=True;TrustServerCertificate=True'
$cn = New-Object System.Data.SqlClient.SqlConnection $cs
$cn.Open()
$cmd = $cn.CreateCommand()
$cmd.CommandText = 'SELECT TOP 5 BillID, BillCode, OrderID, BranchIdSnapshot, BranchNameSnapshot, TableIdSnapshot, TableNameSnapshot, BillTime, EmployeeID FROM dbo.Bills ORDER BY BillID DESC'
$r = $cmd.ExecuteReader()
$rows = @()
while ($r.Read()) {
  $rows += [pscustomobject]@{
    billId = $r['BillID']
    billCode = $r['BillCode']
    orderId = $r['OrderID']
    branchIdSnapshot = if ($r['BranchIdSnapshot'] -eq [System.DBNull]::Value) { $null } else { $r['BranchIdSnapshot'] }
    branchNameSnapshot = if ($r['BranchNameSnapshot'] -eq [System.DBNull]::Value) { $null } else { $r['BranchNameSnapshot'] }
    tableIdSnapshot = if ($r['TableIdSnapshot'] -eq [System.DBNull]::Value) { $null } else { $r['TableIdSnapshot'] }
    tableNameSnapshot = if ($r['TableNameSnapshot'] -eq [System.DBNull]::Value) { $null } else { $r['TableNameSnapshot'] }
    billTime = $r['BillTime']
    employeeId = if ($r['EmployeeID'] -eq [System.DBNull]::Value) { $null } else { $r['EmployeeID'] }
  }
}
$r.Close()
$cn.Close()
$rows | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath 'C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main\.runlogs\debug_bill_row2.json' -Encoding UTF8
Write-Host 'done'
