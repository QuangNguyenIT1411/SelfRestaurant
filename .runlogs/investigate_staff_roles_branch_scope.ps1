$ErrorActionPreference='Stop'
$conn = New-Object System.Data.SqlClient.SqlConnection('Server=(localdb)\MSSQLLocalDB;Database=RESTAURANT_IDENTITY;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=True')
$conn.Open()
try {
  $cmd = $conn.CreateCommand()
  $cmd.CommandText = @"
SELECT e.EmployeeID, e.Name, e.Username, e.BranchID, r.RoleCode, r.RoleName, ISNULL(e.IsActive,0) AS IsActive
FROM Employees e
JOIN EmployeeRoles r ON r.RoleID = e.RoleID
ORDER BY r.RoleCode, e.EmployeeID;
"@
  $da = New-Object System.Data.SqlClient.SqlDataAdapter($cmd)
  $dt = New-Object System.Data.DataTable
  [void]$da.Fill($dt)
  $rows = @($dt.Rows | ForEach-Object {
    [pscustomobject]@{
      employeeId = $_.EmployeeID
      name = $_.Name
      username = $_.Username
      branchId = $_.BranchID
      roleCode = $_.RoleCode
      roleName = $_.RoleName
      isActive = [bool]$_.IsActive
    }
  })
  $rows | ConvertTo-Json -Depth 4
}
finally { $conn.Close() }
