$ErrorActionPreference = 'Stop'
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$body = @{ username = 'cashier_lan'; password = '123456' } | ConvertTo-Json
$login = Invoke-WebRequest -UseBasicParsing -WebSession $session -Uri 'http://localhost:5100/api/gateway/staff/auth/login' -Method POST -ContentType 'application/json' -Body $body
$dash = Invoke-WebRequest -UseBasicParsing -WebSession $session -Uri 'http://localhost:5100/api/gateway/staff/cashier/dashboard' -Method GET
[pscustomobject]@{ login = $login.StatusCode; dashboard = $dash.StatusCode } | ConvertTo-Json
