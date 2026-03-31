$ErrorActionPreference = 'Stop'
$base = 'http://localhost:5100'
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$stamp = Get-Date -Format 'yyyyMMddHHmmss'
$results = New-Object System.Collections.Generic.List[object]

function Add-Result([string]$feature, [bool]$pass, [string]$detail) {
  $results.Add([pscustomobject]@{ feature = $feature; pass = $pass; detail = $detail }) | Out-Null
  $state = if ($pass) { 'PASS' } else { 'FAIL' }
  Write-Output ("[$state] $feature - $detail")
}

function Get-Token([string]$html) {
  $m = [regex]::Match($html, 'name="__RequestVerificationToken"[^>]*value="([^"]+)"', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  if (-not $m.Success) { throw 'Missing anti-forgery token' }
  return $m.Groups[1].Value
}

function Require-Status($response, [int[]]$allowed, [string]$context) {
  if ($null -eq $response) { throw "$context no response" }
  $code = [int]$response.StatusCode
  if ($allowed -notcontains $code) { throw "$context status $code" }
}

function Try-Page([string]$feature, [string]$url, [string]$contains = '') {
  try {
    $r = Invoke-WebRequest $url -WebSession $session -UseBasicParsing
    if ($r.StatusCode -ne 200) { throw "status $($r.StatusCode)" }
    if (-not [string]::IsNullOrWhiteSpace($contains) -and $r.Content -notlike "*$contains*") {
      throw "missing marker: $contains"
    }
    Add-Result $feature $true '200'
  }
  catch {
    Add-Result $feature $false $_.Exception.Message
  }
}

function Find-Id([string]$html, [string[]]$patterns) {
  foreach ($p in $patterns) {
    $m = [regex]::Match($html, $p, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if ($m.Success) { return [int]$m.Groups[1].Value }
  }
  return 0
}

function Save-Summary([string]$path) {
  $passed = ($results | Where-Object { $_.pass }).Count
  $failed = ($results | Where-Object { -not $_.pass }).Count
  $summary = [pscustomobject]@{
    timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    baseUrl = $base
    total = $results.Count
    passed = $passed
    failed = $failed
    results = $results
  }
  $summary | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 $path
  Write-Host "SUMMARY_TOTAL=$($results.Count)"
  Write-Host "SUMMARY_PASSED=$passed"
  Write-Host "SUMMARY_FAILED=$failed"
  return [int]$failed
}

# 0) Health checks
try {
  foreach ($u in @('http://localhost:5101/healthz', 'http://localhost:5102/healthz', 'http://localhost:5103/healthz', 'http://localhost:5105/healthz', 'http://localhost:5100/')) {
    $h = Invoke-WebRequest $u -UseBasicParsing -TimeoutSec 5
    if ($h.StatusCode -lt 200 -or $h.StatusCode -ge 400) { throw "$u status $($h.StatusCode)" }
  }
  Add-Result 'Health' $true 'all service endpoints reachable'
}
catch {
  Add-Result 'Health' $false $_.Exception.Message
  $failed = Save-Summary '.runlogs/admin_full_summary_latest.json'
  exit 1
}

# 1) Login
try {
  $loginPage = Invoke-WebRequest "$base/Staff/Account/Login" -WebSession $session -UseBasicParsing
  $loginToken = Get-Token $loginPage.Content
  $loginResp = Invoke-WebRequest "$base/Staff/Account/Login" -Method Post -WebSession $session -UseBasicParsing -Headers @{ 'X-Requested-With' = 'XMLHttpRequest' } -Body @{
    __RequestVerificationToken = $loginToken
    username = 'admin'
    password = '123456'
    rememberMe = 'false'
  }
  $loginJson = $loginResp.Content | ConvertFrom-Json
  if (-not $loginJson.success) { throw "login failed payload=$($loginResp.Content)" }
  Add-Result 'Admin Login' $true 'success=true'
}
catch {
  Add-Result 'Admin Login' $false $_.Exception.Message
  $failed = Save-Summary '.runlogs/admin_full_summary_latest.json'
  exit 1
}

# 2) Core pages (status check only to avoid locale/encoding mismatch in marker strings)
Try-Page 'Dashboard Page' "$base/Admin/Dashboard"
Try-Page 'Dishes Page' "$base/Admin/Dishes"
Try-Page 'Ingredients Page' "$base/Admin/Ingredients"
Try-Page 'Categories Page' "$base/Admin/Categories"
Try-Page 'Customers Page' "$base/Admin/Customers"
Try-Page 'Employees Page' "$base/Admin/Employees"
Try-Page 'Tables Page' "$base/Admin/Tables"
Try-Page 'Revenue Report Page' "$base/Admin/Reports/Revenue?days=30"
Try-Page 'TopDishes Report Page' "$base/Admin/Reports/TopDishes?days=30&take=10"
Try-Page 'Settings Page' "$base/Admin/Settings"

# 3) Ensure tag helpers rendered (no raw asp-* attributes)
try {
  $checkPaths = @('/Admin/Employees', '/Admin/Customers', '/Admin/Dishes', '/Admin/Ingredients', '/Admin/Tables', '/Admin/Categories')
  $rawFound = @()
  foreach ($p in $checkPaths) {
    $r = Invoke-WebRequest ($base + $p) -WebSession $session -UseBasicParsing
    if ($r.Content -match 'asp-controller=|asp-action=|asp-area=') {
      $rawFound += $p
    }
  }
  if ($rawFound.Count -gt 0) { throw ('raw asp-* attrs on: ' + ($rawFound -join ', ')) }
  Add-Result 'Admin View Render (TagHelper)' $true 'no raw asp-* attributes in HTML'
}
catch {
  Add-Result 'Admin View Render (TagHelper)' $false $_.Exception.Message
}

# 4) Categories CRUD
try {
  $catName = "AUTO_CAT_FULL_$stamp"
  $catName2 = "${catName}_EDIT"

  $catPage = Invoke-WebRequest "$base/Admin/Categories" -WebSession $session -UseBasicParsing
  $catToken = Get-Token $catPage.Content
  $catCreate = Invoke-WebRequest "$base/Admin/Categories/Create" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{
    __RequestVerificationToken = $catToken
    name = $catName
    description = 'auto category full'
    displayOrder = '77'
  }
  Require-Status $catCreate @(302) 'Create category'

  $catList = Invoke-WebRequest "$base/Admin/Categories" -WebSession $session -UseBasicParsing
  $catPattern = '(?is)<tr[^>]*>.*?<input[^>]*name="id"[^>]*value="(\d+)"[^>]*>.*?<input[^>]*name="name"[^>]*value="' + [regex]::Escape($catName) + '"'
  $catMatch = [regex]::Match($catList.Content, $catPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  if (-not $catMatch.Success) { throw 'Cannot find created category row' }
  $catId = [int]$catMatch.Groups[1].Value

  $catToken2 = Get-Token $catList.Content
  $catUpdate = Invoke-WebRequest "$base/Admin/Categories/Update" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{
    __RequestVerificationToken = $catToken2
    id = $catId
    name = $catName2
    description = 'auto category edited'
    displayOrder = '76'
    isActive = 'true'
  }
  Require-Status $catUpdate @(302) 'Update category'

  $catVerify = Invoke-WebRequest "$base/Admin/Categories" -WebSession $session -UseBasicParsing
  if ($catVerify.Content -notlike "*$catName2*") { throw 'Updated category name not found' }

  $catToken3 = Get-Token $catVerify.Content
  $catDelete = Invoke-WebRequest "$base/Admin/Categories/Delete" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{
    __RequestVerificationToken = $catToken3
    id = $catId
  }
  Require-Status $catDelete @(302) 'Delete category'

  Add-Result 'Categories CRUD' $true "categoryId=$catId"
}
catch {
  Add-Result 'Categories CRUD' $false $_.Exception.Message
}

# 5) Dishes CRUD
try {
  $dishName = "AUTO_DISH_FULL_$stamp"
  $dishName2 = "${dishName}_EDIT"

  $dCreatePage = Invoke-WebRequest "$base/Admin/Dishes/Create" -WebSession $session -UseBasicParsing
  $dToken = Get-Token $dCreatePage.Content
  $catId = Find-Id $dCreatePage.Content @('<option\s+value="(\d+)"')
  if ($catId -le 0) { throw 'No category option found for dish create' }

  $dCreate = Invoke-WebRequest "$base/Admin/Dishes/Create" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{
    __RequestVerificationToken = $dToken
    Name = $dishName
    Price = '69000'
    CategoryId = $catId
    Description = 'auto dish full'
    Unit = 'Phan'
    Image = '/images/banh-flan.jpg'
    IsVegetarian = 'false'
    IsDailySpecial = 'false'
    Available = 'true'
    IsActive = 'true'
  }
  Require-Status $dCreate @(302) 'Create dish'

  $dIndex = Invoke-WebRequest "$base/Admin/Dishes?search=$dishName" -WebSession $session -UseBasicParsing
  $dishId = Find-Id $dIndex.Content @('/Admin/Dishes/Edit/(\d+)')
  if ($dishId -le 0) { throw 'Cannot find created dish id' }

  $dEditPage = Invoke-WebRequest "$base/Admin/Dishes/Edit/$dishId" -WebSession $session -UseBasicParsing
  $dEditToken = Get-Token $dEditPage.Content
  $dEdit = Invoke-WebRequest "$base/Admin/Dishes/Edit/$dishId" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{
    __RequestVerificationToken = $dEditToken
    DishId = $dishId
    Name = $dishName2
    Price = '74000'
    CategoryId = $catId
    Description = 'auto dish full edited'
    Unit = 'To'
    Image = '/images/banh-flan.jpg'
    IsVegetarian = 'false'
    IsDailySpecial = 'false'
    Available = 'true'
    IsActive = 'true'
  }
  Require-Status $dEdit @(302) 'Edit dish'

  $dVerify = Invoke-WebRequest "$base/Admin/Dishes?search=$dishName2" -WebSession $session -UseBasicParsing
  if ($dVerify.Content -notlike "*$dishName2*") { throw 'Edited dish not found' }

  $dToken2 = Get-Token $dVerify.Content
  $dDeactivate = Invoke-WebRequest "$base/Admin/Dishes/Deactivate/$dishId" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{ __RequestVerificationToken = $dToken2 }
  Require-Status $dDeactivate @(302) 'Deactivate dish'

  Add-Result 'Dishes CRUD' $true "dishId=$dishId"
}
catch {
  Add-Result 'Dishes CRUD' $false $_.Exception.Message
}

# 6) Ingredients CRUD
try {
  $ingName = "AUTO_ING_FULL_$stamp"
  $ingName2 = "${ingName}_EDIT"

  $iCreatePage = Invoke-WebRequest "$base/Admin/Ingredients/Create" -WebSession $session -UseBasicParsing
  $iToken = Get-Token $iCreatePage.Content
  $iCreate = Invoke-WebRequest "$base/Admin/Ingredients/Create" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{
    __RequestVerificationToken = $iToken
    Name = $ingName
    Unit = 'kg'
    CurrentStock = '15.5'
    ReorderLevel = '3'
    IsActive = 'true'
  }
  Require-Status $iCreate @(302) 'Create ingredient'

  $iIndex = Invoke-WebRequest "$base/Admin/Ingredients?search=$ingName" -WebSession $session -UseBasicParsing
  $ingId = Find-Id $iIndex.Content @('/Admin/Ingredients/Edit/(\d+)')
  if ($ingId -le 0) { throw 'Cannot find created ingredient id' }

  $iEditPage = Invoke-WebRequest "$base/Admin/Ingredients/Edit/$ingId" -WebSession $session -UseBasicParsing
  $iEditToken = Get-Token $iEditPage.Content
  $iEdit = Invoke-WebRequest "$base/Admin/Ingredients/Edit/$ingId" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{
    __RequestVerificationToken = $iEditToken
    IngredientId = $ingId
    Name = $ingName2
    Unit = 'g'
    CurrentStock = '25000'
    ReorderLevel = '1200'
    IsActive = 'true'
  }
  Require-Status $iEdit @(302) 'Edit ingredient'

  $iVerify = Invoke-WebRequest "$base/Admin/Ingredients?search=$ingName2" -WebSession $session -UseBasicParsing
  if ($iVerify.Content -notlike "*$ingName2*") { throw 'Edited ingredient not found' }

  $iToken2 = Get-Token $iVerify.Content
  $iDeactivate = Invoke-WebRequest "$base/Admin/Ingredients/Deactivate/$ingId" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{ __RequestVerificationToken = $iToken2 }
  Require-Status $iDeactivate @(302) 'Deactivate ingredient'

  Add-Result 'Ingredients CRUD' $true "ingredientId=$ingId"
}
catch {
  Add-Result 'Ingredients CRUD' $false $_.Exception.Message
}

# 7) Customers CRUD
try {
  $cusUser = "autocusfull_$stamp"
  $cusName = "Auto Customer Full $stamp"
  $cusPhone = '09' + (Get-Random -Minimum 10000000 -Maximum 99999999)

  $cCreatePage = Invoke-WebRequest "$base/Admin/Customers/Create" -WebSession $session -UseBasicParsing
  $cToken = Get-Token $cCreatePage.Content
  $cCreate = Invoke-WebRequest "$base/Admin/Customers/Create" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{
    __RequestVerificationToken = $cToken
    Name = $cusName
    Username = $cusUser
    Password = '123456'
    PhoneNumber = $cusPhone
    Email = "$cusUser@example.local"
    Gender = 'Nam'
    Address = 'HCM'
    LoyaltyPoints = '0'
    IsActive = 'true'
  }
  Require-Status $cCreate @(302) 'Create customer'

  $cIndex = Invoke-WebRequest "$base/Admin/Customers?search=$cusUser" -WebSession $session -UseBasicParsing
  $cusId = Find-Id $cIndex.Content @('/Admin/Customers/Edit/(\d+)')
  if ($cusId -le 0) { throw 'Cannot find created customer id' }

  $cEditPage = Invoke-WebRequest "$base/Admin/Customers/Edit/$cusId" -WebSession $session -UseBasicParsing
  $cEditToken = Get-Token $cEditPage.Content
  $cEdit = Invoke-WebRequest "$base/Admin/Customers/Edit/$cusId" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{
    __RequestVerificationToken = $cEditToken
    CustomerId = $cusId
    Name = "$cusName EDIT"
    Username = $cusUser
    Password = ''
    PhoneNumber = $cusPhone
    Email = "$cusUser@example.local"
    Gender = 'Nam'
    Address = 'HCM - Edit'
    LoyaltyPoints = '12'
    IsActive = 'true'
  }
  Require-Status $cEdit @(302) 'Edit customer'

  $cVerify = Invoke-WebRequest "$base/Admin/Customers?search=$cusUser" -WebSession $session -UseBasicParsing
  if ($cVerify.Content -notlike "*$cusName EDIT*") { throw 'Edited customer not found' }

  $cToken2 = Get-Token $cVerify.Content
  $cDeactivate = Invoke-WebRequest "$base/Admin/Customers/Deactivate/$cusId" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{ __RequestVerificationToken = $cToken2 }
  Require-Status $cDeactivate @(302) 'Deactivate customer'

  Add-Result 'Customers CRUD' $true "customerId=$cusId"
}
catch {
  Add-Result 'Customers CRUD' $false $_.Exception.Message
}

# 8) Employees CRUD + History
try {
  $empUser = "autoempfull_$stamp"
  $empPhone = '09' + (Get-Random -Minimum 10000000 -Maximum 99999999)
  $empPhone2 = '09' + (Get-Random -Minimum 10000000 -Maximum 99999999)

  $eCreatePage = Invoke-WebRequest "$base/Admin/Employees/Create" -WebSession $session -UseBasicParsing
  $eToken = Get-Token $eCreatePage.Content
  $branchMatch = [regex]::Match($eCreatePage.Content, '<select[^>]*name="BranchId"[\s\S]*?<option\s+value="(\d+)"', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  $roleMatch = [regex]::Match($eCreatePage.Content, '<select[^>]*name="RoleId"[\s\S]*?<option\s+value="(\d+)"', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  $branchId = if ($branchMatch.Success) { [int]$branchMatch.Groups[1].Value } else { 1 }
  $roleId = if ($roleMatch.Success) { [int]$roleMatch.Groups[1].Value } else { 1 }

  $eCreate = Invoke-WebRequest "$base/Admin/Employees/Create" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{
    __RequestVerificationToken = $eToken
    Name = 'Auto Employee Full'
    Username = $empUser
    Password = '123456'
    Phone = $empPhone
    Email = "$empUser@example.local"
    Salary = '8500000'
    Shift = 'Sang'
    IsActive = 'true'
    BranchId = "$branchId"
    RoleId = "$roleId"
  }
  Require-Status $eCreate @(302) 'Create employee'

  $eIndex = Invoke-WebRequest "$base/Admin/Employees?search=$empUser" -WebSession $session -UseBasicParsing
  $empId = Find-Id $eIndex.Content @('/Admin/Employees/Edit/(\d+)')
  if ($empId -le 0) { throw 'Cannot find created employee id' }

  $eEditPage = Invoke-WebRequest "$base/Admin/Employees/Edit/$empId" -WebSession $session -UseBasicParsing
  $eEditToken = Get-Token $eEditPage.Content
  $eEdit = Invoke-WebRequest "$base/Admin/Employees/Edit/$empId" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{
    __RequestVerificationToken = $eEditToken
    EmployeeId = $empId
    Name = 'Auto Employee Full Edit'
    Username = $empUser
    Password = ''
    Phone = $empPhone2
    Email = "$empUser@example.local"
    Salary = '9000000'
    Shift = 'Chieu'
    IsActive = 'true'
    BranchId = "$branchId"
    RoleId = "$roleId"
  }
  Require-Status $eEdit @(302) 'Edit employee'

  $historyRaw = Invoke-WebRequest "$base/Admin/Employees/History/$empId" -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue
  $historyCode = [int]$historyRaw.StatusCode
  if ($historyCode -ne 200 -and $historyCode -ne 302) { throw "History unexpected status $historyCode" }

  $eVerify = Invoke-WebRequest "$base/Admin/Employees?search=$empUser" -WebSession $session -UseBasicParsing
  $eToken2 = Get-Token $eVerify.Content
  $eDeactivate = Invoke-WebRequest "$base/Admin/Employees/Deactivate/$empId" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{ __RequestVerificationToken = $eToken2 }
  Require-Status $eDeactivate @(302) 'Deactivate employee'

  Add-Result 'Employees CRUD + History' $true "employeeId=$empId,historyStatus=$historyCode"
}
catch {
  Add-Result 'Employees CRUD + History' $false $_.Exception.Message
}

# 9) Tables CRUD
try {
  $tableQr = "AUTO-QR-FULL-$stamp"

  $tCreatePage = Invoke-WebRequest "$base/Admin/Tables/Create" -WebSession $session -UseBasicParsing
  $tToken = Get-Token $tCreatePage.Content
  $tBranchMatch = [regex]::Match($tCreatePage.Content, '<select[^>]*name="BranchId"[\s\S]*?<option\s+value="(\d+)"', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  $tStatusMatch = [regex]::Match($tCreatePage.Content, '<select[^>]*name="StatusId"[\s\S]*?<option\s+value="(\d+)"', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  $tBranch = if ($tBranchMatch.Success) { [int]$tBranchMatch.Groups[1].Value } else { 1 }
  $tStatus = if ($tStatusMatch.Success) { [int]$tStatusMatch.Groups[1].Value } else { 1 }

  $tCreate = Invoke-WebRequest "$base/Admin/Tables/Create" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{
    __RequestVerificationToken = $tToken
    BranchId = "$tBranch"
    NumberOfSeats = '6'
    QRCode = $tableQr
    StatusId = "$tStatus"
    IsActive = 'true'
  }
  Require-Status $tCreate @(302) 'Create table'

  $tIndex = Invoke-WebRequest "$base/Admin/Tables?search=$tableQr" -WebSession $session -UseBasicParsing
  $tableId = Find-Id $tIndex.Content @('/Admin/Tables/Edit/(\d+)')
  if ($tableId -le 0) { throw 'Cannot find created table id' }

  $tEditPage = Invoke-WebRequest "$base/Admin/Tables/Edit/$tableId" -WebSession $session -UseBasicParsing
  $tEditToken = Get-Token $tEditPage.Content
  $tEdit = Invoke-WebRequest "$base/Admin/Tables/Edit/$tableId" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{
    __RequestVerificationToken = $tEditToken
    TableId = $tableId
    BranchId = "$tBranch"
    NumberOfSeats = '8'
    QRCode = $tableQr
    StatusId = "$tStatus"
    IsActive = 'true'
  }
  Require-Status $tEdit @(302) 'Edit table'

  $tVerify = Invoke-WebRequest "$base/Admin/Tables?search=$tableQr" -WebSession $session -UseBasicParsing
  if ($tVerify.Content -notlike "*$tableQr*") { throw 'Edited table not found' }

  $tToken2 = Get-Token $tVerify.Content
  $tDeactivate = Invoke-WebRequest "$base/Admin/Tables/Deactivate/$tableId" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{ __RequestVerificationToken = $tToken2 }
  Require-Status $tDeactivate @(302) 'Deactivate table'

  Add-Result 'Tables CRUD' $true "tableId=$tableId"
}
catch {
  Add-Result 'Tables CRUD' $false $_.Exception.Message
}

# 10) Settings save
try {
  $sPage = Invoke-WebRequest "$base/Admin/Settings" -WebSession $session -UseBasicParsing
  $sToken = Get-Token $sPage.Content
  $name = ([regex]::Match($sPage.Content, 'name="Name"[^>]*value="([^"]*)"')).Groups[1].Value
  $username = ([regex]::Match($sPage.Content, 'name="Username"[^>]*value="([^"]*)"')).Groups[1].Value
  $phone = ([regex]::Match($sPage.Content, 'name="Phone"[^>]*value="([^"]*)"')).Groups[1].Value
  $email = ([regex]::Match($sPage.Content, 'name="Email"[^>]*value="([^"]*)"')).Groups[1].Value

  $sPost = Invoke-WebRequest "$base/Admin/Settings" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{
    __RequestVerificationToken = $sToken
    Name = $name
    Username = $username
    Phone = $phone
    Email = $email
    CurrentPassword = ''
    NewPassword = ''
    ConfirmPassword = ''
  }
  Require-Status $sPost @(302) 'Save settings profile'
  Add-Result 'Settings Save Profile' $true '302 redirect'
}
catch {
  Add-Result 'Settings Save Profile' $false $_.Exception.Message
}

$failed = Save-Summary '.runlogs/admin_full_summary_latest.json'
if ($failed -gt 0) { exit 1 }
