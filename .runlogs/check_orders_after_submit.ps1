$ErrorActionPreference='Stop'
function J($session,$url,$method='Get',$body=$null){
  if($null -ne $body){ return Invoke-RestMethod -Uri $url -Method $method -WebSession $session -ContentType 'application/json' -Body ($body|ConvertTo-Json -Depth 10) }
  return Invoke-RestMethod -Uri $url -Method $method -WebSession $session
}
$c=New-Object Microsoft.PowerShell.Commands.WebRequestSession
$r=Get-Random -Minimum 10000 -Maximum 99999
$u="cust$r"
J $c 'http://localhost:5100/api/gateway/customer/dev/reset-test-state' 'Post' | Out-Null
J $c 'http://localhost:5100/api/gateway/customer/auth/register' 'Post' @{name='Khach Test';username=$u;password='123456';phoneNumber="0909$r";email="$u@example.com";gender='Nam';address='HCM'} | Out-Null
J $c 'http://localhost:5100/api/gateway/customer/auth/login' 'Post' @{username=$u;password='123456'} | Out-Null
J $c 'http://localhost:5100/api/gateway/customer/context/table' 'Post' @{tableId=1;branchId=1} | Out-Null
$menu=J $c 'http://localhost:5100/api/gateway/customer/menu'
$dish=$menu.menu.categories[0].dishes[0]
J $c 'http://localhost:5100/api/gateway/customer/order/items' 'Post' @{dishId=$dish.dishId;quantity=1;note='chef flow'} | Out-Null
J $c 'http://localhost:5100/api/gateway/customer/order/submit' 'Post' @{idempotencyKey=[guid]::NewGuid().ToString('N');expectedDiningSessionCode=$null} | Out-Null
Write-Host 'CUSTOMER ORDER:'
J $c 'http://localhost:5100/api/gateway/customer/order' | ConvertTo-Json -Depth 8 | Write-Host
Write-Host 'ORDERS CHEF API:'
Invoke-RestMethod -Uri 'http://localhost:5102/api/branches/1/chef/orders' | ConvertTo-Json -Depth 8 | Write-Host
