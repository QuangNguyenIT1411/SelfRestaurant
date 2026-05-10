$ErrorActionPreference = 'Stop'
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$loginBody = @{ username = 'admin'; password = '123456' } | ConvertTo-Json
$login = Invoke-WebRequest -UseBasicParsing -WebSession $session -Uri 'http://localhost:5100/api/gateway/admin/auth/login' -Method POST -ContentType 'application/json' -Body $loginBody
$tables = Invoke-WebRequest -UseBasicParsing -WebSession $session -Uri 'http://localhost:5100/api/gateway/admin/tables?page=1&pageSize=5' -Method GET
$branches = Invoke-WebRequest -UseBasicParsing -Uri 'http://localhost:5100/api/gateway/customer/branches' -Method GET
$branch1Tables = Invoke-WebRequest -UseBasicParsing -Uri 'http://localhost:5100/api/gateway/customer/branches/1/tables' -Method GET
[pscustomobject]@{
  adminLogin = $login.StatusCode
  adminTables = $tables.StatusCode
  customerBranches = $branches.StatusCode
  customerBranch1Tables = $branch1Tables.StatusCode
  branch1TableCount = ((($branch1Tables.Content | ConvertFrom-Json).tables) | Measure-Object).Count
} | ConvertTo-Json -Depth 5
