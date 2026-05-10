$base='http://localhost:5100'
$s=New-Object Microsoft.PowerShell.Commands.WebRequestSession
$r=Invoke-RestMethod -Method Post -Uri "$base/api/gateway/staff/auth/login" -WebSession $s -ContentType 'application/json' -Body (@{username='cashier_lan';password='123456'}|ConvertTo-Json)
$r | ConvertTo-Json -Depth 10
