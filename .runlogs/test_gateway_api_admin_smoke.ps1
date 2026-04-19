$ErrorActionPreference = 'Stop'
$base = 'http://localhost:5100'
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$stamp = Get-Date -Format 'yyyyMMddHHmmss'
$results = New-Object System.Collections.Generic.List[object]
$createdCategoryId = $null

function Add-Result([string]$feature, [bool]$pass, [string]$detail) {
  $results.Add([pscustomobject]@{ feature = $feature; pass = $pass; detail = $detail }) | Out-Null
  $state = if ($pass) { 'PASS' } else { 'FAIL' }
  Write-Output ("[$state] $feature - $detail")
}

function Invoke-Json([string]$method, [string]$url, $body = $null) {
  $params = @{ Uri = $url; Method = $method; WebSession = $session; UseBasicParsing = $true; Headers = @{ 'Content-Type' = 'application/json' } }
  if ($null -ne $body) { $params.Body = ($body | ConvertTo-Json -Depth 8) }
  $resp = Invoke-WebRequest @params
  if ($resp.Content) { return $resp.Content | ConvertFrom-Json }
  return $null
}

function Save-Summary([string]$path) {
  $summary = [pscustomobject]@{ total = $results.Count; passed = ($results | ? pass).Count; failed = ($results | ? { -not $_.pass }).Count; results = $results }
  $summary | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 $path
  return $summary.failed
}

try {
  $health = Invoke-WebRequest "$base/healthz" -UseBasicParsing -TimeoutSec 10
  if ($health.StatusCode -ne 200) { throw "health $($health.StatusCode)" }
  Add-Result 'Gateway.Api Health' $true '200'

  $login = Invoke-Json 'POST' "$base/api/gateway/admin/auth/login" @{ username = 'admin'; password = '123456' }
  if (-not $login.success) { throw 'login payload not success' }
  $nextPath = if ($null -ne $login.nextPath) { [string]$login.nextPath } else { '' }
  Add-Result 'Admin API Login' $true $nextPath

  $sessionDto = Invoke-Json 'GET' "$base/api/gateway/admin/session"
  if (-not $sessionDto.authenticated) { throw 'session unauthenticated' }
  Add-Result 'Admin Session' $true $sessionDto.staff.username

  foreach ($pathSuffix in @(
    '/api/gateway/admin/dashboard',
    '/api/gateway/admin/categories',
    '/api/gateway/admin/dishes',
    '/api/gateway/admin/ingredients',
    '/api/gateway/admin/tables',
    '/api/gateway/admin/employees',
    '/api/gateway/admin/customers',
    '/api/gateway/admin/reports',
    '/api/gateway/admin/settings'
  )) {
    $resp = Invoke-WebRequest ($base + $pathSuffix) -WebSession $session -UseBasicParsing
    if ($resp.StatusCode -ne 200) { throw "$pathSuffix => $($resp.StatusCode)" }
    Add-Result "GET $pathSuffix" $true '200'
  }

  $catName = "API_ADMIN_CAT_$stamp"
  Invoke-Json 'POST' "$base/api/gateway/admin/categories" @{ name = $catName; description = 'admin api smoke'; displayOrder = 88 } | Out-Null
  $categories = Invoke-Json 'GET' "$base/api/gateway/admin/categories"
  $created = $categories.categories | Where-Object { $_.name -eq $catName } | Select-Object -First 1
  if ($null -eq $created) { throw 'created category not found' }
  $createdCategoryId = [int]$created.categoryId
  Add-Result 'Admin Category Create' $true "categoryId=$createdCategoryId"

  Invoke-Json 'PUT' "$base/api/gateway/admin/categories/$createdCategoryId" @{ name = "${catName}_EDIT"; description = 'edited'; displayOrder = 87; isActive = $true } | Out-Null
  $categories2 = Invoke-Json 'GET' "$base/api/gateway/admin/categories"
  $updated = $categories2.categories | Where-Object { $_.categoryId -eq $createdCategoryId -and $_.name -eq "${catName}_EDIT" } | Select-Object -First 1
  if ($null -eq $updated) { throw 'updated category not found' }
  Add-Result 'Admin Category Update' $true "categoryId=$createdCategoryId"

  Invoke-Json 'DELETE' "$base/api/gateway/admin/categories/$createdCategoryId" | Out-Null
  $categories3 = Invoke-Json 'GET' "$base/api/gateway/admin/categories"
  $deleted = $categories3.categories | Where-Object { $_.categoryId -eq $createdCategoryId } | Select-Object -First 1
  if ($null -ne $deleted) { throw 'category still exists after delete' }
  Add-Result 'Admin Category Delete' $true "categoryId=$createdCategoryId"
  $createdCategoryId = $null

  $html = Invoke-WebRequest "$base/app/admin" -WebSession $session -UseBasicParsing
  if ($html.StatusCode -ne 200) { throw 'app/admin not 200' }
  Add-Result 'Admin SPA Route' $true '200'
}
catch {
  Add-Result 'Admin Smoke' $false $_.Exception.Message
}
finally {
  if ($null -ne $createdCategoryId) {
    try { Invoke-Json 'DELETE' "$base/api/gateway/admin/categories/$createdCategoryId" | Out-Null } catch {}
  }
  try { Invoke-Json 'POST' "$base/api/gateway/admin/auth/logout" @{} | Out-Null } catch {}
}

$failed = Save-Summary 'C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main\.runlogs\gateway_api_admin_smoke_summary.json'
if ($failed -gt 0) { exit 1 }
Write-Host 'PASS admin api smoke'
