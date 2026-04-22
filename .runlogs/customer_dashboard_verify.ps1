$ErrorActionPreference = 'Stop'

$base = 'http://localhost:5100'

$asset = Invoke-WebRequest -UseBasicParsing -Uri "$base/assets/index-D2VC7UhF.js"
$assetContent = [string]$asset.Content

$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
Invoke-RestMethod -Method POST -Uri "$base/api/gateway/customer/auth/login" -WebSession $session -ContentType 'application/json' -Body (@{
    username = 'lan.nguyen'
    password = '123456'
} | ConvertTo-Json) | Out-Null

$branches = Invoke-RestMethod -Method GET -Uri "$base/api/gateway/customer/branches" -WebSession $session
$branchId = [int]$branches[0].branchId
$tables = Invoke-RestMethod -Method GET -Uri "$base/api/gateway/customer/branches/$branchId/tables" -WebSession $session
$table = $tables.tables | Where-Object { $_.isAvailable -eq $true } | Select-Object -First 1
if ($null -eq $table) { $table = $tables.tables | Select-Object -First 1 }

Invoke-RestMethod -Method POST -Uri "$base/api/gateway/customer/context/table" -WebSession $session -ContentType 'application/json' -Body (@{
    tableId = [int]$table.tableId
    branchId = [int]$table.branchId
} | ConvertTo-Json) | Out-Null

$customerSession = Invoke-RestMethod -Method GET -Uri "$base/api/gateway/customer/session" -WebSession $session
$dashboardPage = Invoke-WebRequest -UseBasicParsing -Uri "$base/Customer/Dashboard" -WebSession $session
$homeNewOrderPage = Invoke-WebRequest -UseBasicParsing -Uri "$base/Home/Index?flow=new-order" -WebSession $session

[pscustomobject]@{
    dashboardRouteStatus = [int]$dashboardPage.StatusCode
    homeNewOrderRouteStatus = [int]$homeNewOrderPage.StatusCode
    sessionBranchId = [int]$customerSession.tableContext.branchId
    sessionTableId = [int]$customerSession.tableContext.tableId
    bundleHasBackHomeText = ($assetContent -match 'Quay Về Trang Chủ')
    bundleHasNewOrderFlowLink = ($assetContent -match 'flow=new-order')
    bundleStillContainsHomeStep1 = ($assetContent -match 'Bước 1: Chọn Chi Nhánh')
} | ConvertTo-Json -Depth 5
