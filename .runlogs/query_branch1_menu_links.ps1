$conn = New-Object System.Data.SqlClient.SqlConnection('Server=(localdb)\MSSQLLocalDB;Database=RESTAURANT_CATALOG;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=True')
$conn.Open()
$cmd = $conn.CreateCommand()
$cmd.CommandText = @"
SELECT TOP 20 m.MenuID, m.MenuName, m.[Date], mc.MenuCategoryID, mc.CategoryID, c.Name AS CategoryName
FROM Menus m
JOIN MenuCategory mc ON mc.MenuID = m.MenuID
JOIN Categories c ON c.CategoryID = mc.CategoryID
WHERE m.BranchID = 1 AND (m.IsActive IS NULL OR m.IsActive = 1)
ORDER BY CASE WHEN m.[Date] = CONVERT(date, GETDATE()) THEN 0 ELSE 1 END, m.[Date] DESC, m.MenuID DESC, mc.MenuCategoryID DESC;
"@
$r=$cmd.ExecuteReader(); $dt=New-Object System.Data.DataTable; $dt.Load($r); $conn.Close(); $dt | ConvertTo-Json -Depth 5
