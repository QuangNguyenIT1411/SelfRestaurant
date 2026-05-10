$ErrorActionPreference='Stop'
$base='http://localhost:5100'
$session=New-Object Microsoft.PowerShell.Commands.WebRequestSession
$headers=@{Accept='application/json'}
$loginBody=@{username='admin';password='123456'} | ConvertTo-Json
$null = Invoke-RestMethod -Uri "$base/api/gateway/admin/auth/login" -Method Post -WebSession $session -Headers $headers -ContentType 'application/json' -Body $loginBody
$emps = Invoke-RestMethod -Uri "$base/api/gateway/admin/employees?page=1&pageSize=100" -Method Get -WebSession $session -Headers $headers
$emps.items | Where-Object { $_.roleName -match 'Cashier|Thu ngân|Cashier' -or $_.positionName -match 'Cashier|Thu ngân' } | Select-Object employeeId, fullName, username, branchId, roleName, positionName, isActive | ConvertTo-Json -Depth 5
