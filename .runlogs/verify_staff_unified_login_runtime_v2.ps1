$ErrorActionPreference='Stop'
function New-WebSession { New-Object Microsoft.PowerShell.Commands.WebRequestSession }
function PostJson($session,$url,$body){ Invoke-RestMethod -Method Post -Uri $url -WebSession $session -ContentType 'application/json' -Body (($body)|ConvertTo-Json -Depth 10) }
function GetHtml($url){ (Invoke-WebRequest -Uri $url).Content }
function GetAssetName($html){ $m=[regex]::Match($html,'assets/index-[A-Za-z0-9_-]+\.js'); if(-not $m.Success){ throw 'Asset not found.' }; $m.Value }
$base='http://localhost:5100'
$chefSession=New-WebSession
$cashierSession=New-WebSession
$adminSession=New-WebSession
$chefLogin = PostJson $chefSession "$base/api/gateway/staff/auth/login" @{username='chef_hung';password='123456'}
$chefLogout = PostJson $chefSession "$base/api/gateway/staff/auth/logout" @{}
$cashierLogin = PostJson $cashierSession "$base/api/gateway/staff/auth/login" @{username='cashier_lan';password='123456'}
$cashierLogout = PostJson $cashierSession "$base/api/gateway/staff/cashier/auth/logout" @{}
$adminLogin = PostJson $adminSession "$base/api/gateway/staff/auth/login" @{username='admin';password='123456'}
$adminLogout = PostJson $adminSession "$base/api/gateway/admin/auth/logout" @{}
$sharedLoginStatus = (Invoke-WebRequest -Uri "$base/Staff/Account/Login").StatusCode
$chefHtml = GetHtml "$base/Staff/Account/Login"
$cashierHtml = GetHtml "$base/Staff/Cashier/Index"
$adminHtml = GetHtml "$base/Admin/Dashboard/Index"
$chefAsset = GetAssetName $chefHtml
$cashierAsset = GetAssetName $cashierHtml
$adminAsset = GetAssetName $adminHtml
$chefJs = (Invoke-WebRequest -Uri "$base/$chefAsset").Content
$cashierJs = (Invoke-WebRequest -Uri "$base/app/cashier/$cashierAsset").Content
$adminJs = (Invoke-WebRequest -Uri "$base/app/admin/$adminAsset").Content
[pscustomobject]@{
  sharedLoginRouteStatus = $sharedLoginStatus
  chefLoginNextPath = $chefLogin.nextPath
  cashierLoginNextPath = $cashierLogin.nextPath
  adminLoginNextPath = $adminLogin.nextPath
  chefLogoutNextPath = $chefLogout.nextPath
  cashierLogoutNextPath = $cashierLogout.nextPath
  adminLogoutNextPath = $adminLogout.nextPath
  chefBundleHasSharedLoginPath = $chefJs.Contains('/Staff/Account/Login')
  chefBundleHasChefLanding = $chefJs.Contains('/Staff/Chef/Index')
  chefBundleHasCashierLanding = $chefJs.Contains('/Staff/Cashier/Index')
  chefBundleHasAdminLanding = $chefJs.Contains('/Admin/Dashboard/Index')
  cashierBundleRedirectsLoginToShared = $cashierJs.Contains('/Staff/Account/Login')
  cashierBundleWrongLaneToChef = $cashierJs.Contains('/Staff/Chef/Index')
  cashierBundleWrongLaneToAdmin = $cashierJs.Contains('/Admin/Dashboard/Index')
  adminBundleRedirectsLoginToShared = $adminJs.Contains('/Staff/Account/Login')
  adminBundleWrongLaneToCashier = $adminJs.Contains('/Staff/Cashier/Index')
  adminBundleWrongLaneToChef = $adminJs.Contains('/Staff/Chef/Index')
} | ConvertTo-Json -Depth 6
