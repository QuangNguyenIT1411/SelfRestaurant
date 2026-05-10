$ErrorActionPreference = 'Stop'
$c = New-Object System.Data.SqlClient.SqlConnection('Server=(localdb)\MSSQLLocalDB;Database=RESTAURANT_CATALOG;Trusted_Connection=True;TrustServerCertificate=True')
$c.Open()
try {
  $cmd = $c.CreateCommand()
  $cmd.CommandText = 'SELECT i.IngredientID,i.Name,i.IsActive,(SELECT COUNT(*) FROM DishIngredients di WHERE di.IngredientID=i.IngredientID) AS DishRefs,(SELECT COUNT(*) FROM BusinessAuditLogs b WHERE b.EntityType=''INGREDIENT'' AND TRY_CONVERT(int,b.EntityId)=i.IngredientID) AS AuditRefs FROM Ingredients i WHERE i.IngredientID IN (54,61,69) ORDER BY i.IngredientID'
  $cmd.CommandTimeout = 120
  $r = $cmd.ExecuteReader()
  while($r.Read()) { Write-Output (([string]$r['IngredientID'])+','+([string]$r['Name'])+','+([string]$r['IsActive'])+','+([string]$r['DishRefs'])+','+([string]$r['AuditRefs'])) }
  $r.Close()
}
finally { $c.Close() }
