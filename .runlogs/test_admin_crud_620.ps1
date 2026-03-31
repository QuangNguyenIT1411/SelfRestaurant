$ErrorActionPreference = 'Stop'
$base = 'http://localhost:6200'
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$stamp = Get-Date -Format 'yyyyMMddHHmmss'

function GetToken([string]$html) {
  $m = [regex]::Match($html, 'name="__RequestVerificationToken"[^>]*value="([^"]+)"', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  if(-not $m.Success){ throw 'Missing antiforgery token' }
  return $m.Groups[1].Value
}

function FindId([string]$html, [string[]]$patterns){
  foreach($p in $patterns){
    $m = [regex]::Match($html, $p, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if($m.Success){ return [int]$m.Groups[1].Value }
  }
  return 0
}

function Log([string]$key,[object]$val){ Write-Output ("{0}={1}" -f $key,$val) }

# login
$loginPage = Invoke-WebRequest "$base/Staff/Account/Login" -WebSession $session -UseBasicParsing
$loginToken = GetToken $loginPage.Content
$loginResp = Invoke-WebRequest "$base/Staff/Account/Login" -Method Post -WebSession $session -UseBasicParsing -Headers @{ 'X-Requested-With'='XMLHttpRequest' } -Body @{
  __RequestVerificationToken = $loginToken
  username = 'admin'
  password = '123456'
  rememberMe = 'false'
}
$loginJson = $loginResp.Content | ConvertFrom-Json
Log 'LOGIN_SUCCESS' $loginJson.success
if(-not $loginJson.success){ Log 'LOGIN_PAYLOAD' $loginResp.Content; exit 1 }

# dishes create
$dName = "AUTO620_DISH_$stamp"
$dCreate = Invoke-WebRequest "$base/Admin/Dishes/Create" -WebSession $session -UseBasicParsing
$dToken = GetToken $dCreate.Content
$catMatch = [regex]::Match($dCreate.Content, '<option\s+value="(\d+)"', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
if(-not $catMatch.Success){ throw 'No category option found' }
$catId = [int]$catMatch.Groups[1].Value
$dPost = Invoke-WebRequest "$base/Admin/Dishes/Create" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{
  __RequestVerificationToken = $dToken
  Name = $dName
  Price = '77000'
  CategoryId = $catId
  Description = 'auto test dish'
  Unit = 'Phan'
  Image = '/images/banh-flan.jpg'
  IsVegetarian = 'false'
  IsDailySpecial = 'false'
  Available = 'true'
  IsActive = 'true'
}
Log 'DISH_CREATE_STATUS' $dPost.StatusCode
$dIndex = Invoke-WebRequest "$base/Admin/Dishes?search=$dName" -WebSession $session -UseBasicParsing
$dId = FindId $dIndex.Content @('/Admin/Dishes/Edit/(\d+)', '/Admin/Dishes/Ingredients/(\d+)', 'asp-route-id="(\d+)"')
Log 'DISH_ID' $dId
Log 'DISH_FOUND' ($dIndex.Content -like "*$dName*")

if($dId -gt 0){
  $dEditPage = Invoke-WebRequest "$base/Admin/Dishes/Edit/$dId" -WebSession $session -UseBasicParsing
  $dEditToken = GetToken $dEditPage.Content
  $dEdit = Invoke-WebRequest "$base/Admin/Dishes/Edit/$dId" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{
    __RequestVerificationToken = $dEditToken
    DishId = $dId
    Name = "$dName`_EDIT"
    Price = '88000'
    CategoryId = $catId
    Description = 'edited'
    Unit = 'Phan'
    Image = '/images/banh-flan.jpg'
    IsVegetarian = 'false'
    IsDailySpecial = 'false'
    Available = 'true'
    IsActive = 'true'
  }
  Log 'DISH_EDIT_STATUS' $dEdit.StatusCode

  $dIdx2 = Invoke-WebRequest "$base/Admin/Dishes?search=$($dName)_EDIT" -WebSession $session -UseBasicParsing
  Log 'DISH_EDIT_FOUND' ($dIdx2.Content -like "*$($dName)_EDIT*")

  $dTok2 = GetToken $dIndex.Content
  $dDe = Invoke-WebRequest "$base/Admin/Dishes/Deactivate/$dId" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{ __RequestVerificationToken = $dTok2 }
  Log 'DISH_DEACTIVATE_STATUS' $dDe.StatusCode
}

# ingredients create/edit/deactivate
$iName = "AUTO620_ING_$stamp"
$iCreate = Invoke-WebRequest "$base/Admin/Ingredients/Create" -WebSession $session -UseBasicParsing
$iToken = GetToken $iCreate.Content
$iPost = Invoke-WebRequest "$base/Admin/Ingredients/Create" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{
  __RequestVerificationToken = $iToken
  Name = $iName
  Unit = 'kg'
  CurrentStock = '12.5'
  ReorderLevel = '3'
  IsActive = 'true'
}
Log 'ING_CREATE_STATUS' $iPost.StatusCode
$iIndex = Invoke-WebRequest "$base/Admin/Ingredients?search=$iName" -WebSession $session -UseBasicParsing
$iId = FindId $iIndex.Content @('/Admin/Ingredients/Edit/(\d+)', 'asp-route-id="(\d+)"')
Log 'ING_ID' $iId
Log 'ING_FOUND' ($iIndex.Content -like "*$iName*")
if($iId -gt 0){
  $iEditPage = Invoke-WebRequest "$base/Admin/Ingredients/Edit/$iId" -WebSession $session -UseBasicParsing
  $iEditToken = GetToken $iEditPage.Content
  $iEdit = Invoke-WebRequest "$base/Admin/Ingredients/Edit/$iId" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{
    __RequestVerificationToken = $iEditToken
    IngredientId = $iId
    Name = "$iName`_EDIT"
    Unit = 'kg'
    CurrentStock = '21'
    ReorderLevel = '4'
    IsActive = 'true'
  }
  Log 'ING_EDIT_STATUS' $iEdit.StatusCode
  $iIdx2 = Invoke-WebRequest "$base/Admin/Ingredients?search=$($iName)_EDIT" -WebSession $session -UseBasicParsing
  Log 'ING_EDIT_FOUND' ($iIdx2.Content -like "*$($iName)_EDIT*")

  $iTok2 = GetToken $iIndex.Content
  $iDe = Invoke-WebRequest "$base/Admin/Ingredients/Deactivate/$iId" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{ __RequestVerificationToken = $iTok2 }
  Log 'ING_DEACTIVATE_STATUS' $iDe.StatusCode
}

# customers create/edit/deactivate
$cUser = "autocus620_$stamp"
$cName = "Auto Cus 620"
$cPhone = '09' + (Get-Random -Minimum 10000000 -Maximum 99999999)
$cCreate = Invoke-WebRequest "$base/Admin/Customers/Create" -WebSession $session -UseBasicParsing
$cToken = GetToken $cCreate.Content
$cPost = Invoke-WebRequest "$base/Admin/Customers/Create" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{
  __RequestVerificationToken = $cToken
  Name = $cName
  Username = $cUser
  Password = '123456'
  PhoneNumber = $cPhone
  Email = "$cUser@example.local"
  Gender = 'Nam'
  Address = 'HCM'
  LoyaltyPoints = '0'
  IsActive = 'true'
}
Log 'CUS_CREATE_STATUS' $cPost.StatusCode
$cIndex = Invoke-WebRequest "$base/Admin/Customers?search=$cUser" -WebSession $session -UseBasicParsing
$cId = FindId $cIndex.Content @('/Admin/Customers/Edit/(\d+)', 'asp-route-id="(\d+)"')
Log 'CUS_ID' $cId
Log 'CUS_FOUND' ($cIndex.Content -like "*$cUser*")
if($cId -gt 0){
  $cEditPage = Invoke-WebRequest "$base/Admin/Customers/Edit/$cId" -WebSession $session -UseBasicParsing
  $cEditToken = GetToken $cEditPage.Content
  $cEdit = Invoke-WebRequest "$base/Admin/Customers/Edit/$cId" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{
    __RequestVerificationToken = $cEditToken
    CustomerId = $cId
    Name = "$cName EDIT"
    Username = $cUser
    Password = ''
    PhoneNumber = $cPhone
    Email = "$cUser@example.local"
    Gender = 'Nam'
    Address = 'HCM'
    LoyaltyPoints = '11'
    IsActive = 'true'
  }
  Log 'CUS_EDIT_STATUS' $cEdit.StatusCode
  $cIdx2 = Invoke-WebRequest "$base/Admin/Customers?search=$cUser" -WebSession $session -UseBasicParsing
  Log 'CUS_EDIT_FOUND' ($cIdx2.Content -like "*$cName EDIT*")

  $cTok2 = GetToken $cIndex.Content
  $cDe = Invoke-WebRequest "$base/Admin/Customers/Deactivate/$cId" -Method Post -WebSession $session -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{ __RequestVerificationToken = $cTok2 }
  Log 'CUS_DEACTIVATE_STATUS' $cDe.StatusCode
}
