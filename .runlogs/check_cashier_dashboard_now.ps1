$base='http://localhost:5100'
$s=New-Object Microsoft.PowerShell.Commands.WebRequestSession
Invoke-RestMethod -Method Post -Uri "$base/api/gateway/staff/auth/login" -WebSession $s -ContentType 'application/json' -Body (@{username='cashier_lan';password='123456'}|ConvertTo-Json) | Out-Null
$r=Invoke-RestMethod -Method Get -Uri "$base/api/gateway/staff/cashier/dashboard" -WebSession $s
$r | ConvertTo-Json -Depth 8
