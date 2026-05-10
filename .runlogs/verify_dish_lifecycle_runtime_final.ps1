param(
  [int]$SafeDishId,
  [string]$SafeDishName
)
$ErrorActionPreference = 'Stop'
$base='http://localhost:5100'
function Flatten-Dishes($menuScreen){ $items=@(); foreach($c in @($menuScreen.menu.categories)){ foreach($d in @($c.dishes)){ $items += $d } }; return $items }
function PostJson($session,$url,$body){ Invoke-RestMethod -Method Post -Uri $url -WebSession $session -ContentType 'application/json' -Body ($body|ConvertTo-Json -Depth 10) }
function DeleteJson($session,$url){ Invoke-RestMethod -Method Delete -Uri $url -WebSession $session }
$admin = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$customer = New-Object Microsoft.PowerShell.Commands.WebRequestSession
PostJson $admin "$base/api/gateway/staff/auth/login" @{username='admin';password='123456'} | Out-Null
PostJson $customer "$base/api/gateway/customer/auth/login" @{username='lan.nguyen';password='123456'} | Out-Null
PostJson $customer "$base/api/gateway/customer/context/table" @{branchId=1;tableId=19} | Out-Null
$menuBefore = Invoke-RestMethod -Method Get -Uri "$base/api/gateway/customer/menu" -WebSession $customer
$beforeDish = @(Flatten-Dishes $menuBefore | Where-Object { $_.dishId -eq $SafeDishId } | Select-Object -First 1)
$pauseResp = PostJson $admin "$base/api/gateway/admin/dishes/$SafeDishId/availability" @{available=$false}
$menuAfterPause = Invoke-RestMethod -Method Get -Uri "$base/api/gateway/customer/menu" -WebSession $customer
$pausedDish = @(Flatten-Dishes $menuAfterPause | Where-Object { $_.dishId -eq $SafeDishId } | Select-Object -First 1)
$deleteResp = DeleteJson $admin "$base/api/gateway/admin/dishes/$SafeDishId"
$menuAfterDelete = Invoke-RestMethod -Method Get -Uri "$base/api/gateway/customer/menu" -WebSession $customer
$afterDeleteDish = @(Flatten-Dishes $menuAfterDelete | Where-Object { $_.dishId -eq $SafeDishId })
try {
  DeleteJson $admin "$base/api/gateway/admin/dishes/15" | Out-Null
  $conflictStatus = 200
  $conflictBody = '{}'
} catch {
  $resp = $_.Exception.Response
  $reader = New-Object System.IO.StreamReader($resp.GetResponseStream())
  $conflictStatus = [int]$resp.StatusCode
  $conflictBody = $reader.ReadToEnd()
}
[pscustomobject]@{
  safeDishId = $SafeDishId
  safeDishName = $SafeDishName
  visibleBefore = ($beforeDish.Count -gt 0)
  availableBefore = if($beforeDish.Count -gt 0){ [bool]$beforeDish[0].available } else { $null }
  pauseMessage = $pauseResp.message
  visibleAfterPause = ($pausedDish.Count -gt 0)
  availableAfterPause = if($pausedDish.Count -gt 0){ [bool]$pausedDish[0].available } else { $null }
  deleteMessage = $deleteResp.message
  visibleAfterDelete = ($afterDeleteDish.Count -gt 0)
  conflictStatus = $conflictStatus
  conflictBody = $conflictBody
} | ConvertTo-Json -Depth 10
