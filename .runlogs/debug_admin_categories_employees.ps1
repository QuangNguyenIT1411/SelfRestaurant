$ErrorActionPreference = 'Stop'
$base = 'http://localhost:5100'
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$stamp = Get-Date -Format 'yyyyMMddHHmmss'

function Get-Token([string]$html){
  $m = [regex]::Match($html, 'name="__RequestVerificationToken"[^>]*value="([^"]+)"', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  if(-not $m.Success){ throw 'Missing anti-forgery token' }
  return $m.Groups[1].Value
}

# login
$loginPage = Invoke-WebRequest "$base/Staff/Account/Login" -WebSession $session -UseBasicParsing
$loginToken = Get-Token $loginPage.Content
$loginResp = Invoke-WebRequest "$base/Staff/Account/Login" -Method Post -WebSession $session -UseBasicParsing -Headers @{ 'X-Requested-With'='XMLHttpRequest' } -Body @{
  __RequestVerificationToken = $loginToken
  username = 'admin'
  password = '123456'
  rememberMe = 'false'
}
$loginJson = $loginResp.Content | ConvertFrom-Json
Write-Output "LOGIN_SUCCESS=$($loginJson.success)"

# categories
$catName = "DBG_CAT_$stamp"
$catName2 = "${catName}_EDIT"
$catPage = Invoke-WebRequest "$base/Admin/Categories" -WebSession $session -UseBasicParsing
$catToken = Get-Token $catPage.Content
$catCreate = Invoke-WebRequest "$base/Admin/Categories/Create" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{
  __RequestVerificationToken = $catToken
  name = $catName
  description = 'debug cat'
  displayOrder = '88'
}
Write-Output "CAT_CREATE_STATUS=$($catCreate.StatusCode)"

$catList = Invoke-WebRequest "$base/Admin/Categories" -WebSession $session -UseBasicParsing
$catPattern = '(?is)<tr[^>]*>.*?<input[^>]*name="id"[^>]*value="(\d+)"[^>]*>.*?<input[^>]*name="name"[^>]*value="' + [regex]::Escape($catName) + '"'
$catMatch = [regex]::Match($catList.Content, $catPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
Write-Output "CAT_ROW_FOUND=$($catMatch.Success)"
if(-not $catMatch.Success){ throw 'Cannot find created category row' }
$catId = [int]$catMatch.Groups[1].Value
Write-Output "CAT_ID=$catId"

$catToken2 = Get-Token $catList.Content
$catUpdate = Invoke-WebRequest "$base/Admin/Categories/Update" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{
  __RequestVerificationToken = $catToken2
  id = $catId
  name = $catName2
  description = 'debug cat edited'
  displayOrder = '87'
  isActive = 'true'
}
Write-Output "CAT_UPDATE_STATUS=$($catUpdate.StatusCode)"

$catVerify = Invoke-WebRequest "$base/Admin/Categories" -WebSession $session -UseBasicParsing
Write-Output "CAT_EDIT_FOUND=$($catVerify.Content -like "*$catName2*")"
$catToken3 = Get-Token $catVerify.Content
$catDelete = Invoke-WebRequest "$base/Admin/Categories/Delete" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{
  __RequestVerificationToken = $catToken3
  id = $catId
}
Write-Output "CAT_DELETE_STATUS=$($catDelete.StatusCode)"

# employees
$empUser = "dbgemp_$stamp"
$empPhone = '09' + (Get-Random -Minimum 10000000 -Maximum 99999999)
$empPhone2 = '09' + (Get-Random -Minimum 10000000 -Maximum 99999999)

$empCreatePage = Invoke-WebRequest "$base/Admin/Employees/Create" -WebSession $session -UseBasicParsing
$empToken = Get-Token $empCreatePage.Content
$branchMatch = [regex]::Match($empCreatePage.Content, '<select[^>]*name="BranchId"[\s\S]*?<option\s+value="(\d+)"', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
$roleMatch = [regex]::Match($empCreatePage.Content, '<select[^>]*name="RoleId"[\s\S]*?<option\s+value="(\d+)"', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
$branchId = if($branchMatch.Success){ $branchMatch.Groups[1].Value } else { '1' }
$roleId = if($roleMatch.Success){ $roleMatch.Groups[1].Value } else { '1' }
Write-Output "EMP_BRANCH=$branchId"
Write-Output "EMP_ROLE=$roleId"

$empCreate = Invoke-WebRequest "$base/Admin/Employees/Create" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{
  __RequestVerificationToken = $empToken
  Name = 'Debug Employee'
  Username = $empUser
  Password = '123456'
  Phone = $empPhone
  Email = "$empUser@example.local"
  Salary = '8500000'
  Shift = 'Sang'
  IsActive = 'true'
  BranchId = $branchId
  RoleId = $roleId
}
Write-Output "EMP_CREATE_STATUS=$($empCreate.StatusCode)"

$empList = Invoke-WebRequest "$base/Admin/Employees?search=$empUser" -WebSession $session -UseBasicParsing
$empIdMatch = [regex]::Match($empList.Content, '/Admin/Employees/Edit/(\d+)', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
Write-Output "EMP_ID_FOUND=$($empIdMatch.Success)"
if(-not $empIdMatch.Success){ throw 'Cannot find employee id after create' }
$empId = [int]$empIdMatch.Groups[1].Value
Write-Output "EMP_ID=$empId"

$empEditPage = Invoke-WebRequest "$base/Admin/Employees/Edit/$empId" -WebSession $session -UseBasicParsing
$empEditToken = Get-Token $empEditPage.Content
$empEdit = Invoke-WebRequest "$base/Admin/Employees/Edit/$empId" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{
  __RequestVerificationToken = $empEditToken
  EmployeeId = $empId
  Name = 'Debug Employee Edit'
  Username = $empUser
  Password = ''
  Phone = $empPhone2
  Email = "$empUser@example.local"
  Salary = '9000000'
  Shift = 'Chieu'
  IsActive = 'true'
  BranchId = $branchId
  RoleId = $roleId
}
Write-Output "EMP_EDIT_STATUS=$($empEdit.StatusCode)"

$empHistory = Invoke-WebRequest "$base/Admin/Employees/History/$empId" -WebSession $session -UseBasicParsing
Write-Output "EMP_HISTORY_STATUS=$($empHistory.StatusCode)"

$empList2 = Invoke-WebRequest "$base/Admin/Employees?search=$empUser" -WebSession $session -UseBasicParsing
$empToken2 = Get-Token $empList2.Content
$empDeactivate = Invoke-WebRequest "$base/Admin/Employees/Deactivate/$empId" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{ __RequestVerificationToken = $empToken2 }
Write-Output "EMP_DEACTIVATE_STATUS=$($empDeactivate.StatusCode)"
