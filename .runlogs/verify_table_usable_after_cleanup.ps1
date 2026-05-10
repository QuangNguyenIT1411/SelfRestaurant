$ErrorActionPreference = 'Stop'
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$body = @{ branchId = 2; tableId = 21 } | ConvertTo-Json
$set = Invoke-WebRequest -UseBasicParsing -WebSession $session -Uri 'http://localhost:5100/api/gateway/customer/context/table' -Method POST -ContentType 'application/json' -Body $body
$menu = Invoke-WebRequest -UseBasicParsing -WebSession $session -Uri 'http://localhost:5100/api/gateway/customer/menu' -Method GET
[pscustomobject]@{ setContext = $set.StatusCode; menu = $menu.StatusCode } | ConvertTo-Json
