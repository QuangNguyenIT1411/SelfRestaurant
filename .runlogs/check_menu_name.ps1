param([string]$Name)
$base='http://localhost:5100'
$s = New-Object Microsoft.PowerShell.Commands.WebRequestSession
Invoke-RestMethod -Method Post -Uri "$base/api/gateway/customer/auth/login" -WebSession $s -ContentType 'application/json' -Body (@{username='lan.nguyen';password='123456'}|ConvertTo-Json) | Out-Null
Invoke-RestMethod -Method Post -Uri "$base/api/gateway/customer/context/table" -WebSession $s -ContentType 'application/json' -Body (@{branchId=1;tableId=19}|ConvertTo-Json) | Out-Null
$menuJson = (Invoke-RestMethod -Method Get -Uri "$base/api/gateway/customer/menu" -WebSession $s | ConvertTo-Json -Depth 8)
if ($menuJson -match [regex]::Escape($Name)) { Write-Output 'VISIBLE' } else { Write-Output 'NOT_VISIBLE' }
