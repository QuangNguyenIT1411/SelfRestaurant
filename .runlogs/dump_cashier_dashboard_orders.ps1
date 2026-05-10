$ErrorActionPreference='Stop'
$base='http://localhost:5100'
$session=New-Object Microsoft.PowerShell.Commands.WebRequestSession
$headers=@{Accept='application/json'}
$loginBody=@{username='cashier_lan';password='123456'} | ConvertTo-Json
$null = Invoke-RestMethod -Uri "$base/api/gateway/staff/cashier/auth/login" -Method Post -WebSession $session -Headers $headers -ContentType 'application/json' -Body $loginBody
$dash = Invoke-RestMethod -Uri "$base/api/gateway/staff/cashier/dashboard?branchId=1" -Method Get -WebSession $session -Headers $headers
$dash.activeOrders | Select-Object orderId, orderCode, status, subtotal, tableId | ConvertTo-Json -Depth 5
