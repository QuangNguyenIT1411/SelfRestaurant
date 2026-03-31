$ErrorActionPreference = 'Stop'
$base = 'http://localhost:5100'
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$stamp = Get-Date -Format 'yyyyMMddHHmmss'
$results = New-Object System.Collections.Generic.List[object]

function Add-Result($feature, $pass, $detail){
  $results.Add([pscustomobject]@{feature=$feature;pass=[bool]$pass;detail=$detail}) | Out-Null
  $state = if($pass){'PASS'}else{'FAIL'}
  Write-Output "[$state] $feature - $detail"
}

function Get-Token([string]$html){
  $m = [regex]::Match($html, 'name="__RequestVerificationToken"[^>]*value="([^"]+)"', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  if(-not $m.Success){ throw 'Missing anti-forgery token' }
  return $m.Groups[1].Value
}

function Check-Page([string]$feature, [string]$url, [string]$marker=''){
  try {
    $r = Invoke-WebRequest $url -WebSession $session -UseBasicParsing
    if($r.StatusCode -ne 200){ throw "status $($r.StatusCode)" }
    if($marker -and $r.Content -notlike "*$marker*"){ throw "missing marker: $marker" }
    Add-Result $feature $true '200'
  }
  catch {
    Add-Result $feature $false $_.Exception.Message
  }
}

# login
try {
  $loginPage = Invoke-WebRequest "$base/Staff/Account/Login" -WebSession $session -UseBasicParsing
  $token = Get-Token $loginPage.Content
  $resp = Invoke-WebRequest "$base/Staff/Account/Login" -Method Post -WebSession $session -UseBasicParsing -Headers @{ 'X-Requested-With'='XMLHttpRequest' } -Body @{
    __RequestVerificationToken = $token
    username = 'admin'
    password = '123456'
    rememberMe = 'false'
  }
  $json = $resp.Content | ConvertFrom-Json
  if(-not $json.success){ throw "Login failed: $($resp.Content)" }
  Add-Result 'Admin Login (Extra)' $true 'success=true'
}
catch {
  Add-Result 'Admin Login (Extra)' $false $_.Exception.Message
  $summary = [pscustomobject]@{total=$results.Count;passed=($results|?{$_.pass}).Count;failed=($results|?{-not $_.pass}).Count;results=$results}
  $summary | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 .runlogs/admin_extra_summary_latest.json
  exit 1
}

# dashboard/reports/settings page checks
Check-Page 'Dashboard Page Extra' "$base/Admin/Dashboard"
Check-Page 'Revenue Report Page Extra' "$base/Admin/Reports/Revenue?days=30"
Check-Page 'TopDishes Report Page Extra' "$base/Admin/Reports/TopDishes?days=30&take=10"
Check-Page 'Settings Page Extra' "$base/Admin/Settings"

# settings save
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
  if([int]$sPost.StatusCode -ne 302){ throw "status $($sPost.StatusCode)" }
  Add-Result 'Settings Save Profile' $true '302 redirect'
}
catch {
  Add-Result 'Settings Save Profile' $false $_.Exception.Message
}

# categories CRUD
try {
  $catName = "AUTO_CAT2_$stamp"
  $catPage = Invoke-WebRequest "$base/Admin/Categories" -WebSession $session -UseBasicParsing
  $catToken = Get-Token $catPage.Content
  $cCreate = Invoke-WebRequest "$base/Admin/Categories/Create" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{
    __RequestVerificationToken = $catToken
    name = $catName
    description = 'auto test category'
    displayOrder = '97'
  }
  if([int]$cCreate.StatusCode -ne 302){ throw "Create status $($cCreate.StatusCode)" }

  $catList = Invoke-WebRequest "$base/Admin/Categories" -WebSession $session -UseBasicParsing
  $idMatches = [regex]::Matches($catList.Content, 'name="id"\s+value="(\d+)"', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  if($idMatches.Count -eq 0){ throw 'No category ids found' }
  $catId = ($idMatches | ForEach-Object { [int]$_.Groups[1].Value } | Measure-Object -Maximum).Maximum

  $catToken2 = Get-Token $catList.Content
  $newCatName = "${catName}_EDIT"
  $cUpdate = Invoke-WebRequest "$base/Admin/Categories/Update" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{
    __RequestVerificationToken = $catToken2
    id = $catId
    name = $newCatName
    description = 'edited'
    displayOrder = '96'
    isActive = 'true'
  }
  if([int]$cUpdate.StatusCode -ne 302){ throw "Update status $($cUpdate.StatusCode)" }

  $catCheck = Invoke-WebRequest "$base/Admin/Categories" -WebSession $session -UseBasicParsing
  if($catCheck.Content -notlike "*$newCatName*"){ throw 'Updated category name not found' }

  $catToken3 = Get-Token $catCheck.Content
  $cDelete = Invoke-WebRequest "$base/Admin/Categories/Delete" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{
    __RequestVerificationToken = $catToken3
    id = $catId
  }
  if([int]$cDelete.StatusCode -ne 302){ throw "Delete status $($cDelete.StatusCode)" }

  Add-Result 'Categories CRUD (Extra)' $true "categoryId=$catId"
}
catch {
  Add-Result 'Categories CRUD (Extra)' $false $_.Exception.Message
}

# employees CRUD + history
try {
  $eUser = "autoemp2_$stamp"
  $ePhone = '09' + (Get-Random -Minimum 10000000 -Maximum 99999999)
  $ePhone2 = '09' + (Get-Random -Minimum 10000000 -Maximum 99999999)

  $eCreatePage = Invoke-WebRequest "$base/Admin/Employees/Create" -WebSession $session -UseBasicParsing
  $eToken = Get-Token $eCreatePage.Content
  $branch = ([regex]::Match($eCreatePage.Content, 'name="BranchId"[\s\S]*?<option\s+value="(\d+)"', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)).Groups[1].Value
  $role = ([regex]::Match($eCreatePage.Content, 'name="RoleId"[\s\S]*?<option\s+value="(\d+)"', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)).Groups[1].Value
  if([string]::IsNullOrWhiteSpace($branch)){ $branch = '1' }
  if([string]::IsNullOrWhiteSpace($role)){ $role = '1' }

  $eCreate = Invoke-WebRequest "$base/Admin/Employees/Create" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{
    __RequestVerificationToken = $eToken
    Name = 'Auto Employee Extra'
    Username = $eUser
    Password = '123456'
    Phone = $ePhone
    Email = "$eUser@example.local"
    Salary = '8500000'
    Shift = 'Sang'
    IsActive = 'true'
    BranchId = $branch
    RoleId = $role
  }
  if([int]$eCreate.StatusCode -ne 302){ throw "Create status $($eCreate.StatusCode)" }

  $eList = Invoke-WebRequest "$base/Admin/Employees?search=$eUser" -WebSession $session -UseBasicParsing
  $eIdMatch = [regex]::Match($eList.Content, '/Admin/Employees/Edit/(\d+)', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  if(-not $eIdMatch.Success){ throw 'Cannot find employee id' }
  $eId = [int]$eIdMatch.Groups[1].Value

  $eEditPage = Invoke-WebRequest "$base/Admin/Employees/Edit/$eId" -WebSession $session -UseBasicParsing
  $eEditToken = Get-Token $eEditPage.Content
  $eEdit = Invoke-WebRequest "$base/Admin/Employees/Edit/$eId" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{
    __RequestVerificationToken = $eEditToken
    EmployeeId = $eId
    Name = 'Auto Employee Extra Edit'
    Username = $eUser
    Password = ''
    Phone = $ePhone2
    Email = "$eUser@example.local"
    Salary = '9000000'
    Shift = 'Chieu'
    IsActive = 'true'
    BranchId = $branch
    RoleId = $role
  }
  if([int]$eEdit.StatusCode -ne 302){ throw "Edit status $($eEdit.StatusCode)" }

  $eHist = Invoke-WebRequest "$base/Admin/Employees/History/$eId" -WebSession $session -UseBasicParsing
  if([int]$eHist.StatusCode -ne 200){ throw "History status $($eHist.StatusCode)" }

  $eList2 = Invoke-WebRequest "$base/Admin/Employees?search=$eUser" -WebSession $session -UseBasicParsing
  $eToken2 = Get-Token $eList2.Content
  $eDe = Invoke-WebRequest "$base/Admin/Employees/Deactivate/$eId" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{ __RequestVerificationToken = $eToken2 }
  if([int]$eDe.StatusCode -ne 302){ throw "Deactivate status $($eDe.StatusCode)" }

  Add-Result 'Employees CRUD + History (Extra)' $true "employeeId=$eId"
}
catch {
  Add-Result 'Employees CRUD + History (Extra)' $false $_.Exception.Message
}

# tables CRUD
try {
  $qr = "AUTO-QR2-$stamp"
  $tCreatePage = Invoke-WebRequest "$base/Admin/Tables/Create" -WebSession $session -UseBasicParsing
  $tToken = Get-Token $tCreatePage.Content
  $tBranch = ([regex]::Match($tCreatePage.Content, 'name="BranchId"[\s\S]*?<option\s+value="(\d+)"', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)).Groups[1].Value
  $tStatus = ([regex]::Match($tCreatePage.Content, 'name="StatusId"[\s\S]*?<option\s+value="(\d+)"', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)).Groups[1].Value
  if([string]::IsNullOrWhiteSpace($tBranch)){ $tBranch = '1' }
  if([string]::IsNullOrWhiteSpace($tStatus)){ $tStatus = '1' }

  $tCreate = Invoke-WebRequest "$base/Admin/Tables/Create" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{
    __RequestVerificationToken = $tToken
    BranchId = $tBranch
    NumberOfSeats = '5'
    QRCode = $qr
    StatusId = $tStatus
    IsActive = 'true'
  }
  if([int]$tCreate.StatusCode -ne 302){ throw "Create status $($tCreate.StatusCode)" }

  $tList = Invoke-WebRequest "$base/Admin/Tables?search=$qr" -WebSession $session -UseBasicParsing
  $tIdMatch = [regex]::Match($tList.Content, '/Admin/Tables/Edit/(\d+)', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  if(-not $tIdMatch.Success){ throw 'Cannot find table id' }
  $tId = [int]$tIdMatch.Groups[1].Value

  $tEditPage = Invoke-WebRequest "$base/Admin/Tables/Edit/$tId" -WebSession $session -UseBasicParsing
  $tEditToken = Get-Token $tEditPage.Content
  $tEdit = Invoke-WebRequest "$base/Admin/Tables/Edit/$tId" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{
    __RequestVerificationToken = $tEditToken
    TableId = $tId
    BranchId = $tBranch
    NumberOfSeats = '7'
    QRCode = $qr
    StatusId = $tStatus
    IsActive = 'true'
  }
  if([int]$tEdit.StatusCode -ne 302){ throw "Edit status $($tEdit.StatusCode)" }

  $tList2 = Invoke-WebRequest "$base/Admin/Tables?search=$qr" -WebSession $session -UseBasicParsing
  $tToken2 = Get-Token $tList2.Content
  $tDe = Invoke-WebRequest "$base/Admin/Tables/Deactivate/$tId" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{ __RequestVerificationToken = $tToken2 }
  if([int]$tDe.StatusCode -ne 302){ throw "Deactivate status $($tDe.StatusCode)" }

  Add-Result 'Tables CRUD (Extra)' $true "tableId=$tId"
}
catch {
  Add-Result 'Tables CRUD (Extra)' $false $_.Exception.Message
}

$passed = ($results | Where-Object { $_.pass }).Count
$failed = ($results | Where-Object { -not $_.pass }).Count
$summary = [pscustomobject]@{ timestamp=(Get-Date).ToString('yyyy-MM-dd HH:mm:ss'); total=$results.Count; passed=$passed; failed=$failed; results=$results }
$summary | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 .runlogs/admin_extra_summary_latest.json
Write-Output "SUMMARY_TOTAL=$($results.Count)"
Write-Output "SUMMARY_PASSED=$passed"
Write-Output "SUMMARY_FAILED=$failed"
if($failed -gt 0){ exit 1 }
