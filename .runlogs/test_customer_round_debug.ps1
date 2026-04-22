$ErrorActionPreference='Stop'
$s=New-Object Microsoft.PowerShell.Commands.WebRequestSession
function Step($name,[scriptblock]$block){ Write-Host "STEP:$name"; & $block }
function J($url,$method='Get',$body=$null){
  try {
    if($null -ne $body){ return Invoke-RestMethod -Uri $url -Method $method -WebSession $s -ContentType 'application/json' -Body ($body|ConvertTo-Json -Depth 10) }
    return Invoke-RestMethod -Uri $url -Method $method -WebSession $s
  } catch {
    Write-Host "FAIL_URL:$url METHOD:$method"
    if($_.Exception.Response){ $reader=New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream()); $resp=$reader.ReadToEnd(); Write-Host "RESP:$resp" }
    throw
  }
}
$rand=Get-Random -Minimum 10000 -Maximum 99999
$username="cust$rand"
$email="$username@example.com"
$phone="0909$rand"
$pw='123456'
Step 'reset' { J 'http://localhost:5100/api/gateway/customer/dev/reset-test-state' 'Post' | Out-Null }
Step 'register' { J 'http://localhost:5100/api/gateway/customer/auth/register' 'Post' @{name='Khach Test';username=$username;password=$pw;phoneNumber=$phone;email=$email;gender='Nam';address='HCM'} | ConvertTo-Json -Depth 5 | Write-Host }
Step 'login' { J 'http://localhost:5100/api/gateway/customer/auth/login' 'Post' @{username=$username;password=$pw} | ConvertTo-Json -Depth 5 | Write-Host }
Step 'context' { J 'http://localhost:5100/api/gateway/customer/context/table' 'Post' @{tableId=1;branchId=1} | ConvertTo-Json -Depth 5 | Write-Host }
Step 'menu' { $global:menu=J 'http://localhost:5100/api/gateway/customer/menu'; Write-Host ('dishes=' + @($menu.menu.dishes).Count + ' cats=' + @($menu.menu.categories).Count) }
Step 'add' { $global:dish=$menu.menu.categories[0].dishes[0]; $global:order1=J 'http://localhost:5100/api/gateway/customer/order/items' 'Post' @{dishId=$dish.dishId;quantity=1;note='test note'}; $order1 | ConvertTo-Json -Depth 5 | Write-Host }
Step 'quantity' { $global:itemId=$order1.items[0].itemId; J ("http://localhost:5100/api/gateway/customer/order/items/{0}/quantity" -f $itemId) 'Patch' @{quantity=2} | ConvertTo-Json -Depth 5 | Write-Host }
Step 'note' { J ("http://localhost:5100/api/gateway/customer/order/items/{0}/note" -f $itemId) 'Patch' @{note='updated note'} | ConvertTo-Json -Depth 5 | Write-Host }
Step 'get items' { $global:items=J 'http://localhost:5100/api/gateway/customer/order/items'; $items | ConvertTo-Json -Depth 5 | Write-Host }
Step 'submit' { $global:submitKey=[guid]::NewGuid().ToString('N'); J 'http://localhost:5100/api/gateway/customer/order/submit' 'Post' @{idempotencyKey=$submitKey;expectedDiningSessionCode=$items.diningSessionCode} | ConvertTo-Json -Depth 5 | Write-Host }
