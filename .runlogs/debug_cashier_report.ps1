$s = New-Object Microsoft.PowerShell.Commands.WebRequestSession
Invoke-RestMethod -Uri 'http://localhost:5110/api/gateway/staff/cashier/auth/login' -Method Post -WebSession $s -ContentType 'application/json' -Body (@{ username='cashier_lan'; password='123456' } | ConvertTo-Json) | Out-Null
$history = Invoke-RestMethod -Uri 'http://localhost:5110/api/gateway/staff/cashier/history?take=5' -Method Get -WebSession $s
$report = Invoke-RestMethod -Uri 'http://localhost:5110/api/gateway/staff/cashier/report?date=2026-04-10' -Method Get -WebSession $s
$history | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath 'C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main\.runlogs\debug_cashier_history.json' -Encoding UTF8
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath 'C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main\.runlogs\debug_cashier_report.json' -Encoding UTF8
Write-Host 'done'
