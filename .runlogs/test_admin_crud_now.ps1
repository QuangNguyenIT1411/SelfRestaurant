$ErrorActionPreference = 'Stop'
$base = 'http://localhost:5100'
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$stamp = Get-Date -Format 'yyyyMMddHHmmss'

function GetToken([string]$html) {
  $m = [regex]::Match($html, 'name="__RequestVerificationToken"[^>]*value="([^"]+)"', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  if(-not $m.Success){ throw 'Missing antiforgery token' }
  return $m.Groups[1].Value
}

function GetFirstCategoryId([string]$html) {
  $matches = [regex]::Matches($html, '<option\s+value="(\d+)"', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  foreach($m in $matches){
    $id = [int]$m.Groups[1].Value
    if($id -gt 0){ return $id }
  }
  throw 'No category id found'
}

function FindIdFromIndex([string]$html, [string]$pattern) {
  $m = [regex]::Match($html, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  if(-not $m.Success){ return 0 }
  return [int]$m.Groups[1].Value
}

# 1) Staff admin login
$loginPage = Invoke-WebRequest "$base/Staff/Account/Login" -WebSession $session -UseBasicParsing
$token = GetToken $loginPage.Content
$loginResp = Invoke-WebRequest "$base/Staff/Account/Login" -Method Post -WebSession $session -UseBasicParsing -Headers @{ 'X-Requested-With'='XMLHttpRequest' } -Body @{
  __RequestVerificationToken = $token
  username = 'admin'
  password = '123456'
  rememberMe = 'false'
}
$loginJson = $loginResp.Content | ConvertFrom-Json
if(-not $loginJson.success){ throw "Admin login failed: $($loginResp.Content)" }
Write-Output "LOGIN=OK"

# 2) Dishes create
$dishName = "AUTO_NOW_DISH_$stamp"
$dCreatePage = Invoke-WebRequest "$base/Admin/Dishes/Create" -WebSession $session -UseBasicParsing
$dToken = GetToken $dCreatePage.Content
$catId = GetFirstCategoryId $dCreatePage.Content
$dCreateResp = Invoke-WebRequest "$base/Admin/Dishes/Create" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{
  __RequestVerificationToken = $dToken
  Name = $dishName
  Price = '99000'
  CategoryId = $catId
  Description = 'auto test'
  Unit = 'Phan'
  Image = '/images/banh-flan.jpg'
  IsVegetarian = 'false'
  IsDailySpecial = 'false'
  Available = 'true'
  IsActive = 'true'
}
Write-Output ("DISH_CREATE_STATUS=" + $dCreateResp.StatusCode)

$dIndex = Invoke-WebRequest "$base/Admin/Dishes?search=$dishName" -WebSession $session -UseBasicParsing
$dishId = FindIdFromIndex $dIndex.Content '/Admin/Dishes/Edit/(\d+)'
Write-Output ("DISH_ID=" + $dishId)

# 3) Ingredient create
$ingName = "AUTO_NOW_ING_$stamp"
$iCreatePage = Invoke-WebRequest "$base/Admin/Ingredients/Create" -WebSession $session -UseBasicParsing
$iToken = GetToken $iCreatePage.Content
$iCreateResp = Invoke-WebRequest "$base/Admin/Ingredients/Create" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{
  __RequestVerificationToken = $iToken
  Name = $ingName
  Unit = 'kg'
  CurrentStock = '20'
  ReorderLevel = '5'
  IsActive = 'true'
}
Write-Output ("ING_CREATE_STATUS=" + $iCreateResp.StatusCode)

$iIndex = Invoke-WebRequest "$base/Admin/Ingredients?search=$ingName" -WebSession $session -UseBasicParsing
$ingId = FindIdFromIndex $iIndex.Content '/Admin/Ingredients/Edit/(\d+)'
Write-Output ("ING_ID=" + $ingId)

# 4) Customer create
$cUser = "autocus_$stamp"
$cPhone = "09" + (Get-Random -Minimum 10000000 -Maximum 99999999)
$cCreatePage = Invoke-WebRequest "$base/Admin/Customers/Create" -WebSession $session -UseBasicParsing
$cToken = GetToken $cCreatePage.Content
$cCreateResp = Invoke-WebRequest "$base/Admin/Customers/Create" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{
  __RequestVerificationToken = $cToken
  Name = 'Auto Cus'
  Username = $cUser
  Password = '123456'
  PhoneNumber = $cPhone
  Email = "$cUser@example.local"
  Gender = 'Nam'
  Address = 'HCM'
  LoyaltyPoints = '0'
  IsActive = 'true'
}
Write-Output ("CUS_CREATE_STATUS=" + $cCreateResp.StatusCode)

$cIndex = Invoke-WebRequest "$base/Admin/Customers?search=$cUser" -WebSession $session -UseBasicParsing
$cusId = FindIdFromIndex $cIndex.Content '/Admin/Customers/Edit/(\d+)'
Write-Output ("CUS_ID=" + $cusId)

# 5) Deactivate created rows if found
if($dishId -gt 0){
  $dtok = GetToken $dIndex.Content
  $dDe = Invoke-WebRequest "$base/Admin/Dishes/Deactivate/$dishId" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{ __RequestVerificationToken = $dtok }
  Write-Output ("DISH_DEACTIVATE_STATUS=" + $dDe.StatusCode)
}
if($ingId -gt 0){
  $itok = GetToken $iIndex.Content
  $iDe = Invoke-WebRequest "$base/Admin/Ingredients/Deactivate/$ingId" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{ __RequestVerificationToken = $itok }
  Write-Output ("ING_DEACTIVATE_STATUS=" + $iDe.StatusCode)
}
if($cusId -gt 0){
  $ctok = GetToken $cIndex.Content
  $cDe = Invoke-WebRequest "$base/Admin/Customers/Deactivate/$cusId" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{ __RequestVerificationToken = $ctok }
  Write-Output ("CUS_DEACTIVATE_STATUS=" + $cDe.StatusCode)
}
