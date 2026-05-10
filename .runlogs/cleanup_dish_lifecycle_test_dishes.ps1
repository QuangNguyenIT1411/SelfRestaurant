$base='http://localhost:5100'
$admin = New-Object Microsoft.PowerShell.Commands.WebRequestSession
Invoke-RestMethod -Method Post -Uri "$base/api/gateway/staff/auth/login" -WebSession $admin -ContentType 'application/json' -Body (@{username='admin';password='123456'}|ConvertTo-Json) | Out-Null
foreach($dishId in 3156,3157,3158,3163){
  try { Invoke-RestMethod -Method Delete -Uri "$base/api/gateway/admin/dishes/$dishId" -WebSession $admin | Out-Null; Write-Output "DELETED:$dishId" }
  catch { Write-Output "SKIP:$dishId" }
}
