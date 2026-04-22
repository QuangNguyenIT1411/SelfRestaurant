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
$reg=J 'http://localhost:5100/api/gateway/customer/auth/register' 'Post' @{name='Khach Test';username=$username;password=$pw;phoneNumber=$phone;email=$email;gender='Nam';address='HCM'}
$login=J 'http://localhost:5100/api/gateway/customer/auth/login' 'Post' @{username=$username;password=$pw}
J 'http://localhost:5100/api/gateway/customer/context/table' 'Post' @{tableId=1;branchId=1} | Out-Null
$menu=J 'http://localhost:5100/api/gateway/customer/menu'
$dish=$menu.menu.categories[0].dishes[0]
$order1=J 'http://localhost:5100/api/gateway/customer/order/items' 'Post' @{dishId=$dish.dishId;quantity=1;note='test note'}
$itemId=$order1.items[0].itemId
J ("http://localhost:5100/api/gateway/customer/order/items/{0}/quantity" -f $itemId) 'Patch' @{quantity=2} | Out-Null
J ("http://localhost:5100/api/gateway/customer/order/items/{0}/note" -f $itemId) 'Patch' @{note='updated note'} | Out-Null
$items=J 'http://localhost:5100/api/gateway/customer/order/items'
$submitKey=[guid]::NewGuid().ToString('N')
$submit=J 'http://localhost:5100/api/gateway/customer/order/submit' 'Post' @{idempotencyKey=$submitKey;expectedDiningSessionCode=$items.diningSessionCode}
try { $submitReplay=J 'http://localhost:5100/api/gateway/customer/order/submit' 'Post' @{idempotencyKey=$submitKey;expectedDiningSessionCode=$items.diningSessionCode}; $replayOk=$true } catch { $submitReplay=$_.Exception.Message; $replayOk=$false }
$order=J 'http://localhost:5100/api/gateway/customer/order'
[pscustomobject]@{
  RegisterNext=$reg.nextPath
  LoginNext=$login.nextPath
  DishId=$dish.dishId
  ItemId=$itemId
  ItemCount=@($items.items).Count
  Subtotal=$items.subtotal
  SubmitMessage=$submit.message
  ReplayOk=$replayOk
  ReplayResult=if($replayOk){$submitReplay.message}else{$submitReplay}
  OrderId=$order.orderId
  DiningSessionCode=$order.diningSessionCode
  ItemStatus=($order.items | Select-Object -First 1).status
} | ConvertTo-Json -Depth 5
