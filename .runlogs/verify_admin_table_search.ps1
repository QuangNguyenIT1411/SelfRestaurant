$ErrorActionPreference = 'Stop'
$base = 'http://localhost:5100'
$s = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$null = Invoke-WebRequest -Uri "$base/api/gateway/admin/auth/login" -Method Post -WebSession $s -UseBasicParsing -ContentType 'application/json' -Body (@{ username='admin'; password='123456' } | ConvertTo-Json)
$search36 = (Invoke-WebRequest -Uri "$base/api/gateway/admin/tables?search=36&page=1&pageSize=5" -WebSession $s -UseBasicParsing).Content | ConvertFrom-Json
$filterBranch3 = (Invoke-WebRequest -Uri "$base/api/gateway/admin/tables?branchId=3&page=1&pageSize=5" -WebSession $s -UseBasicParsing).Content | ConvertFrom-Json
[ordered]@{
  search36Count = @($search36.tables.items).Count
  search36FirstTableId = @($search36.tables.items | Select-Object -First 1)[0].tableId
  branch3Count = @($filterBranch3.tables.items).Count
  branch3FirstBranchId = @($filterBranch3.tables.items | Select-Object -First 1)[0].branchId
} | ConvertTo-Json -Depth 6
