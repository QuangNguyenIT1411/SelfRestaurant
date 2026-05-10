$ErrorActionPreference = "Stop"

$base = "http://localhost:5100"
$gatewayAdmin = "$base/api/gateway/admin"
$identityDirect = "http://localhost:5104/api/identity/admin"
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession

function Invoke-Api {
    param(
        [string]$Method,
        [string]$Url,
        [object]$Body = $null
    )

    $jsonBody = if ($null -ne $Body) { $Body | ConvertTo-Json -Depth 10 -Compress } else { $null }

    try {
        $result = Invoke-RestMethod -Method $Method -Uri $Url -WebSession $session -ContentType "application/json" -Body $jsonBody
        return [pscustomobject]@{
            StatusCode = 200
            Json = $result
        }
    }
    catch {
        $response = $_.Exception.Response
        if ($null -eq $response) { throw }
        $statusCode = [int]$response.StatusCode
        $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
        $content = $reader.ReadToEnd()
        return [pscustomobject]@{
            StatusCode = $statusCode
            Json = if ($content) { $content | ConvertFrom-Json } else { $null }
        }
    }
}

$login = Invoke-Api -Method POST -Url "$gatewayAdmin/auth/login" -Body @{
    username = "admin"
    password = "123456"
}

$sessionInfo = Invoke-Api -Method GET -Url "$gatewayAdmin/session"
$dashboard = Invoke-Api -Method GET -Url "$gatewayAdmin/dashboard"
$tablesScopedBack = Invoke-Api -Method GET -Url "$gatewayAdmin/tables?branchId=2&page=1&pageSize=5"
$employeesScopedBack = Invoke-Api -Method GET -Url "$gatewayAdmin/employees?branchId=2&page=1&pageSize=5"
$reports = Invoke-Api -Method GET -Url "$gatewayAdmin/reports"

$otherBranchEmployee = (Invoke-RestMethod -Method GET -Uri "$identityDirect/employees?branchId=2&page=1&pageSize=1").items | Select-Object -First 1

$crossBranchEmployeeGet = if ($otherBranchEmployee) {
    Invoke-Api -Method GET -Url "$gatewayAdmin/employees/$($otherBranchEmployee.employeeId)"
} else {
    [pscustomobject]@{ StatusCode = $null; Json = $null }
}

$stamp = Get-Date -Format "yyyyMMddHHmmss"
$crossBranchEmployeeCreate = Invoke-Api -Method POST -Url "$gatewayAdmin/employees" -Body @{
    name = "Branch Scope Runtime"
    username = "branch_scope_$stamp"
    password = "123456"
    phone = $null
    email = $null
    salary = $null
    shift = $null
    isActive = $true
    branchId = 2
    roleId = 2
}

$crossBranchTableCreate = Invoke-Api -Method POST -Url "$gatewayAdmin/tables" -Body @{
    branchId = 2
    numberOfSeats = 4
    statusId = 1
    isActive = $true
}

$adminRoute = Invoke-WebRequest -Uri "$base/app/admin/Admin/TablesQR/Index" -WebSession $session -UseBasicParsing
$bundleMatch = [regex]::Match($adminRoute.Content, 'assets/(index-[^"]+\.js)')
$bundleText = if ($bundleMatch.Success) {
    (Invoke-WebRequest -Uri "$base/app/admin/$($bundleMatch.Groups[1].Value)" -WebSession $session -UseBasicParsing).Content
} else {
    ""
}

[pscustomobject]@{
    loginStatus = $login.StatusCode
    adminBranchId = $sessionInfo.Json.staff.branchId
    adminRoleCode = $sessionInfo.Json.staff.roleCode
    dashboardBranches = @($dashboard.Json.branches | ForEach-Object { $_.branchId })
    dashboardLatestEmployeeBranches = @($dashboard.Json.latestEmployees | ForEach-Object { $_.branchId } | Select-Object -Unique)
    scopedTablesStatus = $tablesScopedBack.StatusCode
    scopedTablesReturnedBranches = @($tablesScopedBack.Json.tables.items | ForEach-Object { $_.branchId } | Select-Object -Unique)
    scopedTablesBranchOptions = @($tablesScopedBack.Json.branches | ForEach-Object { $_.branchId })
    scopedEmployeesStatus = $employeesScopedBack.StatusCode
    scopedEmployeesReturnedBranches = @($employeesScopedBack.Json.employees.items | ForEach-Object { $_.branchId } | Select-Object -Unique)
    scopedEmployeesBranchOptions = @($employeesScopedBack.Json.branches | ForEach-Object { $_.branchId })
    reportsStatus = $reports.StatusCode
    reportsRevenueBranchIds = @($reports.Json.revenue.revenueByBranchDate | ForEach-Object { $_.branchId } | Select-Object -Unique)
    crossBranchEmployeeId = $otherBranchEmployee.employeeId
    crossBranchEmployeeGetStatus = $crossBranchEmployeeGet.StatusCode
    crossBranchEmployeeGetMessage = $crossBranchEmployeeGet.Json.message
    crossBranchEmployeeCreateStatus = $crossBranchEmployeeCreate.StatusCode
    crossBranchEmployeeCreateMessage = $crossBranchEmployeeCreate.Json.message
    crossBranchTableCreateStatus = $crossBranchTableCreate.StatusCode
    crossBranchTableCreateMessage = $crossBranchTableCreate.Json.message
    adminRouteStatus = [int]$adminRoute.StatusCode
    servedAdminBundleHasBranchScopeMessage = $bundleText -match "Bạn chỉ có thể quản lý bàn thuộc chi nhánh của mình."
} | ConvertTo-Json -Depth 10
