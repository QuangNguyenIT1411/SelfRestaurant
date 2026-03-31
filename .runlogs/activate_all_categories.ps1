$cats=Invoke-WebRequest 'http://localhost:5101/api/categories?includeInactive=true' -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
foreach($c in $cats){
  if(-not [bool]$c.isActive){
    $body=@{ name=$c.name; description=$c.description; displayOrder=[int]$c.displayOrder; isActive=$true } | ConvertTo-Json
    try{
      Invoke-WebRequest ("http://localhost:5101/api/categories/"+[int]$c.categoryId) -Method Put -ContentType 'application/json' -Body $body -UseBasicParsing | Out-Null
      Write-Output ("activated categoryId="+[int]$c.categoryId)
    }catch{
      Write-Output ("failed categoryId="+[int]$c.categoryId+" :: "+$_.Exception.Message)
    }
  }
}
