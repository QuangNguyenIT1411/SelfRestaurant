$ts = Get-Date -Format 'yyyyMMddHHmmss'
$name = "DEL_VIS_$ts"
$conn = New-Object System.Data.SqlClient.SqlConnection('Server=(localdb)\MSSQLLocalDB;Database=RESTAURANT_CATALOG;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=True')
$conn.Open()
$cmd = $conn.CreateCommand()
$cmd.CommandText = @"
DECLARE @menuCategoryId INT = (
  SELECT TOP 1 mc.MenuCategoryID
  FROM MenuCategory mc
  INNER JOIN Menus m ON m.MenuID = mc.MenuID
  WHERE m.BranchID = 1 AND ISNULL(m.IsActive,1)=1 AND mc.CategoryID = 1
  ORDER BY m.[Date] DESC, m.MenuID DESC, mc.MenuCategoryID DESC
);
DECLARE @dishId INT;
INSERT INTO Dishes (Name, Price, Available, Image, Description, Unit, IsVegetarian, IsDailySpecial, IsActive, CreatedAt, UpdatedAt, CategoryID)
VALUES (@name, 12345, 1, NULL, 'dbg visible', 'phan', 0, 0, 1, GETDATE(), GETDATE(), 1);
SET @dishId = SCOPE_IDENTITY();
INSERT INTO CategoryDish (DisplayOrder, IsAvailable, Note, CreatedAt, UpdatedAt, MenuCategoryID, DishID)
VALUES ((SELECT ISNULL(MAX(DisplayOrder),0)+1 FROM CategoryDish WHERE MenuCategoryID=@menuCategoryId), 1, NULL, GETDATE(), GETDATE(), @menuCategoryId, @dishId);
SELECT @dishId;
"@
[void]$cmd.Parameters.AddWithValue('@name', $name)
$dishId = [int]$cmd.ExecuteScalar()
$conn.Close()
Write-Host "Inserted $dishId $name"

$base='http://localhost:5100'
$s = New-Object Microsoft.PowerShell.Commands.WebRequestSession
Invoke-RestMethod -Method Post -Uri "$base/api/gateway/customer/auth/login" -WebSession $s -ContentType 'application/json' -Body (@{username='lan.nguyen';password='123456'}|ConvertTo-Json) | Out-Null
Invoke-RestMethod -Method Post -Uri "$base/api/gateway/customer/context/table" -WebSession $s -ContentType 'application/json' -Body (@{branchId=1;tableId=19}|ConvertTo-Json) | Out-Null
$menuJson = (Invoke-RestMethod -Method Get -Uri "$base/api/gateway/customer/menu" -WebSession $s | ConvertTo-Json -Depth 8)
if ($menuJson -match $name) { Write-Host 'VISIBLE' } else { Write-Host 'NOT_VISIBLE' }
