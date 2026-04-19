$ErrorActionPreference = 'Stop'
$base = 'http://localhost:5100'
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$stamp = Get-Date -Format 'MMddHHmmss'
$username = "phase1_$stamp"
$phone = "09$((Get-Random -Minimum 10000000 -Maximum 99999999))"
$password = 'Pass@123'

$branches = Invoke-RestMethod -Uri "$base/api/gateway/customer/branches" -WebSession $session -Method Get
if (-not $branches -or $branches.Count -eq 0) { throw 'No branches returned.' }
$branchId = $branches[0].branchId
$tables = Invoke-RestMethod -Uri "$base/api/gateway/customer/branches/$branchId/tables" -WebSession $session -Method Get
if (-not $tables.tables -or $tables.tables.Count -eq 0) { throw 'No tables returned.' }
$table = $tables.tables[0]
Invoke-RestMethod -Uri "$base/api/gateway/customer/context/table" -WebSession $session -Method Post -ContentType 'application/json' -Body (@{ tableId = $table.tableId; branchId = $table.branchId } | ConvertTo-Json)
Invoke-RestMethod -Uri "$base/api/gateway/customer/auth/register" -WebSession $session -Method Post -ContentType 'application/json' -Body (@{ name = 'Phase1 Test'; username = $username; password = $password; phoneNumber = $phone; email = "$username@example.com" } | ConvertTo-Json)
Invoke-RestMethod -Uri "$base/api/gateway/customer/auth/login" -WebSession $session -Method Post -ContentType 'application/json' -Body (@{ username = $username; password = $password } | ConvertTo-Json)
$sessionState = Invoke-RestMethod -Uri "$base/api/gateway/customer/session" -WebSession $session -Method Get
$menu = Invoke-RestMethod -Uri "$base/api/gateway/customer/menu" -WebSession $session -Method Get
[pscustomobject]@{
  Username = $username
  Phone = $phone
  BranchId = $branchId
  TableId = $table.tableId
  Authenticated = $sessionState.authenticated
  MenuCategories = @($menu.menu.categories).Count
} | ConvertTo-Json -Depth 5
