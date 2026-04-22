$ErrorActionPreference='Stop'
$s=New-Object Microsoft.PowerShell.Commands.WebRequestSession
function J($url,$method='Get',$body=$null){
  if($null -ne $body){ return Invoke-RestMethod -Uri $url -Method $method -WebSession $s -ContentType 'application/json' -Body ($body|ConvertTo-Json -Depth 10) }
  return Invoke-RestMethod -Uri $url -Method $method -WebSession $s
}
$rand=Get-Random -Minimum 10000 -Maximum 99999
$username="cust$rand"
$email="$username@example.com"
$phone="0909$rand"
$pw='123456'
J 'http://localhost:5100/api/gateway/customer/dev/reset-test-state' 'Post' | Out-Null
J 'http://localhost:5100/api/gateway/customer/auth/register' 'Post' @{name='Khach Test';username=$username;password=$pw;phoneNumber=$phone;email=$email;gender='Nam';address='HCM'} | Out-Null
J 'http://localhost:5100/api/gateway/customer/auth/login' 'Post' @{username=$username;password=$pw} | Out-Null
J 'http://localhost:5100/api/gateway/customer/context/table' 'Post' @{tableId=1;branchId=1} | Out-Null
$menu=J 'http://localhost:5100/api/gateway/customer/menu'
$dish=$menu.menu.categories[0].dishes[0]
J 'http://localhost:5100/api/gateway/customer/order/items' 'Post' @{dishId=$dish.dishId;quantity=1;note='test note'} | Out-Null
$key=[guid]::NewGuid().ToString('N')
$submit1=J 'http://localhost:5100/api/gateway/customer/order/submit' 'Post' @{idempotencyKey=$key;expectedDiningSessionCode=$null}
$submit2=J 'http://localhost:5100/api/gateway/customer/order/submit' 'Post' @{idempotencyKey=$key;expectedDiningSessionCode=$null}
$order=J 'http://localhost:5100/api/gateway/customer/order'
[pscustomobject]@{Submit1=$submit1.message;Submit2=$submit2.message;OrderId=$order.orderId;ItemCount=@($order.items).Count;Status=($order.items|Select-Object -First 1).status;DiningSessionCode=$order.diningSessionCode} | ConvertTo-Json -Depth 5
