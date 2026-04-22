$ErrorActionPreference='Stop'
function Step($name,[scriptblock]$block){ Write-Host "STEP:$name"; & $block }
function J($session,$url,$method='Get',$body=$null){
  try {
    if($null -ne $body){ return Invoke-RestMethod -Uri $url -Method $method -WebSession $session -ContentType 'application/json' -Body ($body|ConvertTo-Json -Depth 10) }
    return Invoke-RestMethod -Uri $url -Method $method -WebSession $session
  } catch {
    Write-Host "FAIL_URL:$url METHOD:$method"
    if($_.Exception.Response){ $reader=New-Object IO.StreamReader($_.Exception.Response.GetResponseStream()); Write-Host ("RESP:" + $reader.ReadToEnd()); Write-Host ("STATUS=" + $_.Exception.Response.StatusCode.value__); Write-Host ("ALLOW=" + $_.Exception.Response.Headers['Allow']) }
    throw
  }
}
$customer=New-Object Microsoft.PowerShell.Commands.WebRequestSession
$chef=New-Object Microsoft.PowerShell.Commands.WebRequestSession
$rand=Get-Random -Minimum 10000 -Maximum 99999
$username="cust$rand"
$email="$username@example.com"
$phone="0909$rand"
$pw='123456'
Step 'reset' { J $customer 'http://localhost:5100/api/gateway/customer/dev/reset-test-state' 'Post' | Out-Null }
Step 'register' { J $customer 'http://localhost:5100/api/gateway/customer/auth/register' 'Post' @{name='Khach Test';username=$username;password=$pw;phoneNumber=$phone;email=$email;gender='Nam';address='HCM'} | Out-Null }
Step 'customer login' { J $customer 'http://localhost:5100/api/gateway/customer/auth/login' 'Post' @{username=$username;password=$pw} | Out-Null }
Step 'set table' { J $customer 'http://localhost:5100/api/gateway/customer/context/table' 'Post' @{tableId=1;branchId=1} | Out-Null }
Step 'menu' { $global:menu=J $customer 'http://localhost:5100/api/gateway/customer/menu'; $global:dish=$menu.menu.categories[0].dishes[0] }
Step 'add' { J $customer 'http://localhost:5100/api/gateway/customer/order/items' 'Post' @{dishId=$dish.dishId;quantity=1;note='chef flow'} | Out-Null }
Step 'submit' { J $customer 'http://localhost:5100/api/gateway/customer/order/submit' 'Post' @{idempotencyKey=[guid]::NewGuid().ToString('N');expectedDiningSessionCode=$null} | Out-Null }
Step 'chef login' { J $chef 'http://localhost:5100/api/gateway/staff/auth/login' 'Post' @{username='chef_hung';password='123456'} | Out-Null }
Step 'dash1' { $global:dash1=J $chef 'http://localhost:5100/api/gateway/staff/chef/dashboard'; Write-Host ('pending=' + @($dash1.pendingOrders).Count + ' preparing=' + @($dash1.preparingOrders).Count + ' ready=' + @($dash1.readyOrders).Count) }
Step 'pick order' { $global:order=@($dash1.pendingOrders + $dash1.preparingOrders + $dash1.readyOrders) | Select-Object -First 1; $global:item=$order.items | Select-Object -First 1; $global:startUrl=("http://localhost:5100/api/gateway/staff/chef/orders/{0}/items/{1}/start" -f $order.orderId,$item.itemId); $global:readyUrl=("http://localhost:5100/api/gateway/staff/chef/orders/{0}/items/{1}/ready" -f $order.orderId,$item.itemId); Write-Host ('STARTURL=' + $startUrl); Write-Host ('READYURL=' + $readyUrl) }
Step 'start item' { J $chef $startUrl 'Post' | ConvertTo-Json -Depth 5 | Write-Host }
Step 'ready item' { J $chef $readyUrl 'Post' | ConvertTo-Json -Depth 5 | Write-Host }
