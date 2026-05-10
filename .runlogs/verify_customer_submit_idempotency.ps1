$ErrorActionPreference = 'Stop'

function Read-ErrorResponse($Exception) {
  $response = $Exception.Response
  if ($null -eq $response) { return [pscustomobject]@{ raw = $Exception.Message; status = 0; json = $null } }
  $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
  $raw = $reader.ReadToEnd()
  $reader.Close()
  $json = $null
  if (-not [string]::IsNullOrWhiteSpace($raw)) { try { $json = $raw | ConvertFrom-Json } catch {} }
  [pscustomobject]@{ raw = $raw; status = [int]$response.StatusCode; json = $json }
}

function Invoke-RestApi {
  param([string]$Method='GET',[string]$Url,$Session=$null,$Body=$null)
  $params = @{ Uri = $Url; Method = $Method; TimeoutSec = 60 }
  if ($null -ne $Session) { $params.WebSession = $Session }
  if ($null -ne $Body) { $params.ContentType = 'application/json'; $params.Body = ($Body | ConvertTo-Json -Depth 20) }
  try {
    $json = Invoke-RestMethod @params
    return [pscustomobject]@{ ok = $true; status = 200; json = $json; raw = ($json | ConvertTo-Json -Depth 20 -Compress) }
  } catch {
    $err = Read-ErrorResponse $_.Exception
    return [pscustomobject]@{ ok = $false; status = $err.status; json = $err.json; raw = $err.raw }
  }
}

$base = 'http://localhost:5100'
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$tableId = $null

try {
  $login = Invoke-RestApi -Method POST -Url "$base/api/gateway/customer/auth/login" -Session $session -Body @{ username = 'lan.nguyen'; password = '123456' }
  if (-not $login.ok) { throw "login failed: $($login.raw)" }
  $branches = Invoke-RestApi -Url "$base/api/gateway/customer/branches" -Session $session
  $branchId = [int]$branches.json[0].branchId
  $tables = Invoke-RestApi -Url "$base/api/gateway/customer/branches/$branchId/tables" -Session $session
  $table = @($tables.json.tables | Where-Object { $_.isAvailable -eq $true } | Select-Object -First 1)
  if ($table.Count -eq 0) { $table = @($tables.json.tables | Select-Object -First 1) }
  $tableId = [int]$table[0].tableId
  [void](Invoke-RestApi -Method POST -Url "$base/api/gateway/customer/context/table" -Session $session -Body @{ tableId = $tableId; branchId = $branchId })
  $menu = Invoke-RestApi -Url "$base/api/gateway/customer/menu" -Session $session
  $dish = @($menu.json.menu.categories[0].dishes | Where-Object { $_.available -eq $true } | Select-Object -First 1)[0]
  [void](Invoke-RestApi -Method POST -Url "$base/api/gateway/customer/order/items" -Session $session -Body @{ dishId = [int]$dish.dishId; quantity = 1; note = 'IDEMPOTENCY_VERIFY' })
  $key = [guid]::NewGuid().ToString('N')
  $submit1 = Invoke-RestApi -Method POST -Url "$base/api/gateway/customer/order/submit" -Session $session -Body @{ idempotencyKey = $key; expectedDiningSessionCode = $null }
  $submit2 = Invoke-RestApi -Method POST -Url "$base/api/gateway/customer/order/submit" -Session $session -Body @{ idempotencyKey = $key; expectedDiningSessionCode = $null }
  $order = Invoke-RestApi -Url "$base/api/gateway/customer/order" -Session $session

  [ordered]@{
    firstSubmitStatus = $submit1.status
    secondSubmitStatus = $submit2.status
    firstSubmitOk = $submit1.ok
    secondSubmitOk = $submit2.ok
    secondSubmitCode = if ($submit2.json) { $submit2.json.code } else { $null }
    secondSubmitMessage = if ($submit2.json) { $submit2.json.message } else { $submit2.raw }
    activeOrderStatus = $order.json.statusCode
    activeOrderId = $order.json.orderId
  } | ConvertTo-Json -Depth 6
}
finally {
  if ($tableId) {
    try { [void](Invoke-RestApi -Method POST -Url "$base/api/gateway/customer/context/table/reset" -Session $session) } catch {}
  }
}
