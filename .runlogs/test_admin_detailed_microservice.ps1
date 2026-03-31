$ErrorActionPreference = 'Stop'
$base = 'http://localhost:5100'
$stamp = Get-Date -Format 'yyyyMMddHHmmss'
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$results = New-Object System.Collections.Generic.List[object]

function Add-Result([string]$Feature, [bool]$Pass, [string]$Detail){
  $results.Add([pscustomobject]@{ feature=$Feature; pass=$Pass; detail=$Detail }) | Out-Null
  $state = if($Pass){'PASS'}else{'FAIL'}
  Write-Output ("[$state] $Feature - $Detail")
}

function Get-Token([string]$html){
  $m = [regex]::Match($html, 'name="__RequestVerificationToken"[^>]*value="([^"]+)"', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  if(-not $m.Success){ throw 'Missing anti-forgery token' }
  return $m.Groups[1].Value
}

function Get-InputValue([string]$html, [string]$name, [string]$default=''){
  $pattern = "<input[^>]*name=[\"']" + [regex]::Escape($name) + "[\"'][^>]*>"
  $m = [regex]::Match($html, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  if(-not $m.Success){ return $default }
  $v = [regex]::Match($m.Value, "value=[\"']([^\"']*)[\"']", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  if($v.Success){ return $v.Groups[1].Value }
  return $default
}

function Find-FirstId([string]$html, [string[]]$patterns){
  foreach($p in $patterns){
    $m = [regex]::Match($html, $p, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if($m.Success){ return [int]$m.Groups[1].Value }
  }
  return 0
}

function Require-Status($response, [int[]]$allowed, [string]$ctx){
  if($allowed -notcontains [int]$response.StatusCode){
    throw "$ctx unexpected status $($response.StatusCode)"
  }
}

function Check-Page([string]$feature, [string]$url, [string]$mustContain=''){
  try {
    $r = Invoke-WebRequest $url -WebSession $session -UseBasicParsing
    if($r.StatusCode -ne 200){ throw "status $($r.StatusCode)" }
    if(-not [string]::IsNullOrWhiteSpace($mustContain) -and $r.Content -notlike "*$mustContain*"){
      throw "content missing marker: $mustContain"
    }
    Add-Result $feature $true '200'
  }
  catch {
    Add-Result $feature $false $_.Exception.Message
  }
}

function Write-SummaryAndExit([int]$exitCode){
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
  $summary | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 .runlogs/admin_detailed_summary_latest.json
  Write-Output "SUMMARY_TOTAL=$($results.Count)"
  Write-Output "SUMMARY_PASSED=$passed"
  Write-Output "SUMMARY_FAILED=$failed"
  exit $exitCode
}

# 0) health
try {
  foreach($u in @('http://localhost:5101/healthz','http://localhost:5102/healthz','http://localhost:5103/healthz','http://localhost:5105/healthz','http://localhost:5100/')){
    $r = Invoke-WebRequest $u -UseBasicParsing -TimeoutSec 5
    if($r.StatusCode -lt 200 -or $r.StatusCode -ge 400){ throw "$u status $($r.StatusCode)" }
  }
  Add-Result 'Health' $true 'all services reachable'
}
catch {
  Add-Result 'Health' $false $_.Exception.Message
  Write-SummaryAndExit 1
}

# 1) login
try {
  $loginPage = Invoke-WebRequest "$base/Staff/Account/Login" -WebSession $session -UseBasicParsing
  $token = Get-Token $loginPage.Content
  $loginResp = Invoke-WebRequest "$base/Staff/Account/Login" -Method Post -WebSession $session -UseBasicParsing -Headers @{ 'X-Requested-With'='XMLHttpRequest' } -Body @{
    __RequestVerificationToken = $token
    username = 'admin'
    password = '123456'
    rememberMe = 'false'
  }
  $j = $loginResp.Content | ConvertFrom-Json
  if(-not $j.success){ throw "login failed: $($loginResp.Content)" }
  Add-Result 'Admin Login' $true 'success=true'
}
catch {
  Add-Result 'Admin Login' $false $_.Exception.Message
  Write-SummaryAndExit 1
}

# 2) page checks
Check-Page 'Dashboard Page' "$base/Admin/Dashboard" 'Tổng quan doanh thu'
Check-Page 'Employees Page' "$base/Admin/Employees" 'Quản lý nhân viên'
Check-Page 'Customers Page' "$base/Admin/Customers" 'Quản lý khách hàng'
Check-Page 'Dishes Page' "$base/Admin/Dishes" 'Quản lý món ăn'
Check-Page 'Ingredients Page' "$base/Admin/Ingredients" 'Quản lý nguyên liệu'
Check-Page 'Categories Page' "$base/Admin/Categories" 'Quản lý danh mục'
Check-Page 'Tables Page' "$base/Admin/Tables" 'Quản lý bàn'
Check-Page 'TablesQR Compat Page' "$base/Admin/TablesQR" 'Quản lý bàn'
Check-Page 'Revenue Report Page' "$base/Admin/Reports/Revenue?days=30" 'Báo cáo doanh thu'
Check-Page 'TopDishes Report Page' "$base/Admin/Reports/TopDishes?days=30&take=10" 'Món ăn được gọi nhiều nhất'
Check-Page 'Settings Page' "$base/Admin/Settings" 'Cài đặt tài khoản'

# 3) categories CRUD
try {
  $catName = "AUTO_CAT_$stamp"
  $catName2 = "${catName}_EDIT"

  $catPage = Invoke-WebRequest "$base/Admin/Categories" -WebSession $session -UseBasicParsing
  $catToken = Get-Token $catPage.Content
  $createResp = Invoke-WebRequest "$base/Admin/Categories/Create" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{
    __RequestVerificationToken = $catToken
    name = $catName
    description = 'auto category'
    displayOrder = '99'
  }
  Require-Status $createResp @(302) 'Create category'

  $catList = Invoke-WebRequest "$base/Admin/Categories" -WebSession $session -UseBasicParsing
  $escCat = [regex]::Escape($catName)
  $catRow = [regex]::Match($catList.Content, "(?is)<tr[^>]*>.*?name=[\"']id[\"']\s+value=[\"'](\d+)[\"'].*?name=[\"']name[\"'][^>]*value=[\"']$escCat[\"']")
  if(-not $catRow.Success){ throw 'Cannot find created category row' }
  $catId = [int]$catRow.Groups[1].Value

  $catToken2 = Get-Token $catList.Content
  $updResp = Invoke-WebRequest "$base/Admin/Categories/Update" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{
    __RequestVerificationToken = $catToken2
    id = $catId
    name = $catName2
    description = 'auto category edited'
    displayOrder = '98'
    isActive = 'true'
  }
  Require-Status $updResp @(302) 'Update category'

  $catVerify = Invoke-WebRequest "$base/Admin/Categories" -WebSession $session -UseBasicParsing
  if($catVerify.Content -notlike "*$catName2*"){ throw 'Updated category name not found' }

  $catToken3 = Get-Token $catVerify.Content
  $delResp = Invoke-WebRequest "$base/Admin/Categories/Delete" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{
    __RequestVerificationToken = $catToken3
    id = $catId
  }
  Require-Status $delResp @(302) 'Delete category'
  Add-Result 'Categories CRUD' $true "categoryId=$catId"
}
catch {
  Add-Result 'Categories CRUD' $false $_.Exception.Message
}

# 4) dishes CRUD + ingredients assignment
try {
  $dishName = "AUTO_DISH_$stamp"
  $dishName2 = "${dishName}_EDIT"

  $dCreatePage = Invoke-WebRequest "$base/Admin/Dishes/Create" -WebSession $session -UseBasicParsing
  $dToken = Get-Token $dCreatePage.Content
  $cat = Find-FirstId $dCreatePage.Content @('<option\s+value="(\d+)"')
  if($cat -le 0){ throw 'No category for dish create' }

  $dCreateResp = Invoke-WebRequest "$base/Admin/Dishes/Create" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{
    __RequestVerificationToken = $dToken
    Name = $dishName
    Price = '65000'
    CategoryId = $cat
    Description = 'auto dish'
    Unit = 'Phan'
    Image = '/images/banh-flan.jpg'
    IsVegetarian = 'false'
    IsDailySpecial = 'false'
    Available = 'true'
    IsActive = 'true'
  }
  Require-Status $dCreateResp @(302) 'Create dish'

  $dIndex = Invoke-WebRequest "$base/Admin/Dishes?search=$dishName" -WebSession $session -UseBasicParsing
  $dishId = Find-FirstId $dIndex.Content @('/Admin/Dishes/Edit/(\d+)','asp-route-id="(\d+)"')
  if($dishId -le 0){ throw 'Cannot find dish id' }

  $dEditPage = Invoke-WebRequest "$base/Admin/Dishes/Edit/$dishId" -WebSession $session -UseBasicParsing
  $dEditToken = Get-Token $dEditPage.Content
  $dEditResp = Invoke-WebRequest "$base/Admin/Dishes/Edit/$dishId" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{
    __RequestVerificationToken = $dEditToken
    DishId = $dishId
    Name = $dishName2
    Price = '72000'
    CategoryId = $cat
    Description = 'auto dish edited'
    Unit = 'To'
    Image = '/images/banh-flan.jpg'
    IsVegetarian = 'false'
    IsDailySpecial = 'false'
    Available = 'true'
    IsActive = 'true'
  }
  Require-Status $dEditResp @(302) 'Edit dish'

  $dVerify = Invoke-WebRequest "$base/Admin/Dishes?search=$dishName2" -WebSession $session -UseBasicParsing
  if($dVerify.Content -notlike "*$dishName2*"){ throw 'Edited dish not found' }

  $dIngPage = Invoke-WebRequest "$base/Admin/Dishes/Ingredients/$dishId" -WebSession $session -UseBasicParsing
  $firstIng = Find-FirstId $dIngPage.Content @('name="ingredientId"\s+value="(\d+)"')
  if($firstIng -gt 0){
    $dAddIng = Invoke-WebRequest "$base/Admin/Dishes/AddIngredient" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{
      dishId = $dishId
      ingredientId = $firstIng
      quantityPerDish = '1.25'
    }
    Require-Status $dAddIng @(302) 'Add dish ingredient'
  }

  $dToken2 = Get-Token $dVerify.Content
  $dDe = Invoke-WebRequest "$base/Admin/Dishes/Deactivate/$dishId" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{ __RequestVerificationToken = $dToken2 }
  Require-Status $dDe @(302) 'Deactivate dish'

  Add-Result 'Dishes CRUD + Ingredient Link' $true "dishId=$dishId"
}
catch {
  Add-Result 'Dishes CRUD + Ingredient Link' $false $_.Exception.Message
}

# 5) ingredients CRUD
try {
  $ingName = "AUTO_ING_$stamp"
  $ingName2 = "${ingName}_EDIT"

  $iCreatePage = Invoke-WebRequest "$base/Admin/Ingredients/Create" -WebSession $session -UseBasicParsing
  $iToken = Get-Token $iCreatePage.Content
  $iCreate = Invoke-WebRequest "$base/Admin/Ingredients/Create" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{
    __RequestVerificationToken = $iToken
    Name = $ingName
    Unit = 'kg'
    CurrentStock = '19.5'
    ReorderLevel = '3'
    IsActive = 'true'
  }
  Require-Status $iCreate @(302) 'Create ingredient'

  $iIndex = Invoke-WebRequest "$base/Admin/Ingredients?search=$ingName" -WebSession $session -UseBasicParsing
  $ingId = Find-FirstId $iIndex.Content @('/Admin/Ingredients/Edit/(\d+)','asp-route-id="(\d+)"')
  if($ingId -le 0){ throw 'Cannot find ingredient id' }

  $iEditPage = Invoke-WebRequest "$base/Admin/Ingredients/Edit/$ingId" -WebSession $session -UseBasicParsing
  $iEditToken = Get-Token $iEditPage.Content
  $iEdit = Invoke-WebRequest "$base/Admin/Ingredients/Edit/$ingId" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{
    __RequestVerificationToken = $iEditToken
    IngredientId = $ingId
    Name = $ingName2
    Unit = 'g'
    CurrentStock = '20500'
    ReorderLevel = '1500'
    IsActive = 'true'
  }
  Require-Status $iEdit @(302) 'Edit ingredient'

  $iVerify = Invoke-WebRequest "$base/Admin/Ingredients?search=$ingName2" -WebSession $session -UseBasicParsing
  if($iVerify.Content -notlike "*$ingName2*"){ throw 'Edited ingredient not found' }

  $iToken2 = Get-Token $iVerify.Content
  $iDe = Invoke-WebRequest "$base/Admin/Ingredients/Deactivate/$ingId" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{ __RequestVerificationToken = $iToken2 }
  Require-Status $iDe @(302) 'Deactivate ingredient'

  Add-Result 'Ingredients CRUD' $true "ingredientId=$ingId"
}
catch {
  Add-Result 'Ingredients CRUD' $false $_.Exception.Message
}

# 6) customers CRUD
try {
  $cusUser = "autocus_$stamp"
  $cusName = "Auto Customer $stamp"
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
  $cusId = Find-FirstId $cIndex.Content @('/Admin/Customers/Edit/(\d+)','asp-route-id="(\d+)"')
  if($cusId -le 0){ throw 'Cannot find customer id' }

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
    LoyaltyPoints = '20'
    IsActive = 'true'
  }
  Require-Status $cEdit @(302) 'Edit customer'

  $cVerify = Invoke-WebRequest "$base/Admin/Customers?search=$cusUser" -WebSession $session -UseBasicParsing
  if($cVerify.Content -notlike "*$cusName EDIT*"){ throw 'Edited customer not found' }

  $cToken2 = Get-Token $cVerify.Content
  $cDe = Invoke-WebRequest "$base/Admin/Customers/Deactivate/$cusId" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{ __RequestVerificationToken = $cToken2 }
  Require-Status $cDe @(302) 'Deactivate customer'

  Add-Result 'Customers CRUD' $true "customerId=$cusId"
}
catch {
  Add-Result 'Customers CRUD' $false $_.Exception.Message
}

# 7) employees CRUD + history
try {
  $empUser = "autoemp_$stamp"
  $empPhone = '09' + (Get-Random -Minimum 10000000 -Maximum 99999999)
  $empPhone2 = '09' + (Get-Random -Minimum 10000000 -Maximum 99999999)

  $eCreatePage = Invoke-WebRequest "$base/Admin/Employees/Create" -WebSession $session -UseBasicParsing
  $eToken = Get-Token $eCreatePage.Content
  $branchId = Find-FirstId $eCreatePage.Content @('name="BranchId"[\s\S]*?<option\s+value="(\d+)"')
  $roleId = Find-FirstId $eCreatePage.Content @('name="RoleId"[\s\S]*?<option\s+value="(\d+)"')
  if($branchId -le 0){ $branchId = 1 }
  if($roleId -le 0){ $roleId = 1 }

  $eCreate = Invoke-WebRequest "$base/Admin/Employees/Create" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{
    __RequestVerificationToken = $eToken
    Name = "Auto Employee $stamp"
    Username = $empUser
    Password = '123456'
    Phone = $empPhone
    Email = "$empUser@example.local"
    Salary = '8000000'
    Shift = 'Sang'
    IsActive = 'true'
    BranchId = $branchId
    RoleId = $roleId
  }
  Require-Status $eCreate @(302) 'Create employee'

  $eIndex = Invoke-WebRequest "$base/Admin/Employees?search=$empUser" -WebSession $session -UseBasicParsing
  $empId = Find-FirstId $eIndex.Content @('/Admin/Employees/Edit/(\d+)','asp-route-id="(\d+)"')
  if($empId -le 0){ throw 'Cannot find employee id' }

  $eEditPage = Invoke-WebRequest "$base/Admin/Employees/Edit/$empId" -WebSession $session -UseBasicParsing
  $eEditToken = Get-Token $eEditPage.Content
  $eEdit = Invoke-WebRequest "$base/Admin/Employees/Edit/$empId" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{
    __RequestVerificationToken = $eEditToken
    EmployeeId = $empId
    Name = "Auto Employee $stamp EDIT"
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
  Require-Status $eEdit @(302) 'Edit employee'

  $eHist = Invoke-WebRequest "$base/Admin/Employees/History/$empId" -WebSession $session -UseBasicParsing
  if($eHist.StatusCode -ne 200){ throw 'Employee history page not reachable' }

  $eVerify = Invoke-WebRequest "$base/Admin/Employees?search=$empUser" -WebSession $session -UseBasicParsing
  if($eVerify.Content -notlike "*$empUser*"){ throw 'Employee not visible after edit' }

  $eToken2 = Get-Token $eVerify.Content
  $eDe = Invoke-WebRequest "$base/Admin/Employees/Deactivate/$empId" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{ __RequestVerificationToken = $eToken2 }
  Require-Status $eDe @(302) 'Deactivate employee'

  Add-Result 'Employees CRUD + History' $true "employeeId=$empId"
}
catch {
  Add-Result 'Employees CRUD + History' $false $_.Exception.Message
}

# 8) tables CRUD
try {
  $tableQr = "AUTO-QR-$stamp"

  $tCreatePage = Invoke-WebRequest "$base/Admin/Tables/Create" -WebSession $session -UseBasicParsing
  $tToken = Get-Token $tCreatePage.Content
  $tBranch = Find-FirstId $tCreatePage.Content @('name="BranchId"[\s\S]*?<option\s+value="(\d+)"')
  $tStatus = Find-FirstId $tCreatePage.Content @('name="StatusId"[\s\S]*?<option\s+value="(\d+)"')
  if($tBranch -le 0){ $tBranch = 1 }
  if($tStatus -le 0){ $tStatus = 1 }

  $tCreate = Invoke-WebRequest "$base/Admin/Tables/Create" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{
    __RequestVerificationToken = $tToken
    BranchId = $tBranch
    NumberOfSeats = '6'
    QRCode = $tableQr
    StatusId = $tStatus
    IsActive = 'true'
  }
  Require-Status $tCreate @(302) 'Create table'

  $tIndex = Invoke-WebRequest "$base/Admin/Tables?search=$tableQr" -WebSession $session -UseBasicParsing
  $tableId = Find-FirstId $tIndex.Content @('/Admin/Tables/Edit/(\d+)','asp-route-id="(\d+)"')
  if($tableId -le 0){ throw 'Cannot find table id' }

  $tEditPage = Invoke-WebRequest "$base/Admin/Tables/Edit/$tableId" -WebSession $session -UseBasicParsing
  $tEditToken = Get-Token $tEditPage.Content
  $tEdit = Invoke-WebRequest "$base/Admin/Tables/Edit/$tableId" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{
    __RequestVerificationToken = $tEditToken
    TableId = $tableId
    BranchId = $tBranch
    NumberOfSeats = '8'
    QRCode = $tableQr
    StatusId = $tStatus
    IsActive = 'true'
  }
  Require-Status $tEdit @(302) 'Edit table'

  $tVerify = Invoke-WebRequest "$base/Admin/Tables?search=$tableQr" -WebSession $session -UseBasicParsing
  if($tVerify.Content -notlike "*$tableQr*"){ throw 'Edited table not found' }

  $tToken2 = Get-Token $tVerify.Content
  $tDe = Invoke-WebRequest "$base/Admin/Tables/Deactivate/$tableId" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{ __RequestVerificationToken = $tToken2 }
  Require-Status $tDe @(302) 'Deactivate table'

  Add-Result 'Tables CRUD' $true "tableId=$tableId"
}
catch {
  Add-Result 'Tables CRUD' $false $_.Exception.Message
}

# 9) settings save
try {
  $sPage = Invoke-WebRequest "$base/Admin/Settings" -WebSession $session -UseBasicParsing
  $sToken = Get-Token $sPage.Content
  $name = Get-InputValue $sPage.Content 'Name'
  $username = Get-InputValue $sPage.Content 'Username'
  $phone = Get-InputValue $sPage.Content 'Phone'
  $email = Get-InputValue $sPage.Content 'Email'

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
  Require-Status $sPost @(302) 'Save settings'
  Add-Result 'Settings Save Profile' $true 'saved without password change'
}
catch {
  Add-Result 'Settings Save Profile' $false $_.Exception.Message
}

$failed = ($results | Where-Object { -not $_.pass }).Count
if($failed -gt 0){ Write-SummaryAndExit 1 } else { Write-SummaryAndExit 0 }
