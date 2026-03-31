$cats=Invoke-WebRequest 'http://localhost:5101/api/categories?includeInactive=true' -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
'Categories:'
$cats | Select-Object categoryId,name,isActive,displayOrder | Format-Table -AutoSize | Out-String | Write-Output
$d=Invoke-WebRequest 'http://localhost:5101/api/admin/dishes?page=1&pageSize=50' -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
'Dishes sample:'
$d.items | Select-Object -First 20 dishId,name,categoryId,categoryName,available,isActive | Format-Table -AutoSize | Out-String | Write-Output
