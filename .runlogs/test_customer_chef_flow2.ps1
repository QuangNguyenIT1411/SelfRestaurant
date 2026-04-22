$ErrorActionPreference='Stop'
function J($session,$url,$method='Get',$body=$null){
  if($null -ne $body){ return Invoke-RestMethod -Uri $url -Method $method -WebSession $session -ContentType 'application/json' -Body ($body|ConvertTo-Json -Depth 10) }
  return Invoke-RestMethod -Uri $url -Method $method -WebSession $session
}
$customer=New-Object Microsoft.PowerShell.Commands.WebRequestSession
$chef=New-Object Microsoft.PowerShell.Commands.WebRequestSession
$rand=Get-Random -Minimum 10000 -Maximum 99999
$username="cust$rand"
$email="$username@example.com"
$phone="0909$rand"
$pw='123456'
J $customer 'http://localhost:5100/api/gateway/customer/dev/reset-test-state' 'Post' | Out-Null
J $customer 'http://localhost:5100/api/gateway/customer/auth/register' 'Post' @{name='Khach Test';username=$username;password=$pw;phoneNumber=$phone;email=$email;gender='Nam';address='HCM'} | Out-Null
J $customer 'http://localhost:5100/api/gateway/customer/auth/login' 'Post' @{username=$username;password=$pw} | Out-Null
J $customer 'http://localhost:5100/api/gateway/customer/context/table' 'Post' @{tableId=1;branchId=1} | Out-Null
$menu=J $customer 'http://localhost:5100/api/gateway/customer/menu'
$dish=$menu.menu.categories[0].dishes[0]
J $customer 'http://localhost:5100/api/gateway/customer/order/items' 'Post' @{dishId=$dish.dishId;quantity=1;note='chef flow'} | Out-Null
J $customer 'http://localhost:5100/api/gateway/customer/order/submit' 'Post' @{idempotencyKey=[guid]::NewGuid().ToString('N');expectedDiningSessionCode=$null} | Out-Null
$login=J $chef 'http://localhost:5100/api/gateway/staff/auth/login' 'Post' @{username='chef_hung';password='123456'}
$dash1=J $chef 'http://localhost:5100/api/gateway/staff/chef/dashboard'
$order=@($dash1.pendingOrders + $dash1.preparingOrders + $dash1.readyOrders) | Select-Object -First 1
$item=$order.items | Select-Object -First 1
$start=J $chef ("http://localhost:5100/api/gateway/staff/chef/orders/{0}/items/{1}/start" -f $order.orderId,$item.itemId) 'Post' @{}
$ready=J $chef ("http://localhost:5100/api/gateway/staff/chef/orders/{0}/items/{1}/ready" -f $order.orderId,$item.itemId) 'Post' @{}
$dash2=J $chef 'http://localhost:5100/api/gateway/staff/chef/dashboard'
$order2=(@($dash2.pendingOrders + $dash2.preparingOrders + $dash2.readyOrders) | Where-Object { $_.orderId -eq $order.orderId } | Select-Object -First 1)
$customerOrder=J $customer 'http://localhost:5100/api/gateway/customer/order'
$notifications=J $customer 'http://localhost:5100/api/gateway/customer/ready-notifications'
[pscustomobject]@{
  ChefLoginNext=$login.nextPath
  OrderId=$order.orderId
  ItemId=$item.itemId
  StartMessage=$start.message
  ReadyMessage=$ready.message
  ChefItemStatus=(($order2.items | Where-Object { $_.itemId -eq $item.itemId } | Select-Object -First 1).status)
  CustomerItemStatus=(($customerOrder.items | Select-Object -First 1).status)
  ReadyNotifications=@($notifications.notifications).Count
} | ConvertTo-Json -Depth 5
