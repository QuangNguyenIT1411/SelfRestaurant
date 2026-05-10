$ErrorActionPreference='Stop'
$base='http://localhost:5100'
$session=New-Object Microsoft.PowerShell.Commands.WebRequestSession
function J($u,$m='GET',$body=$null){
  $args=@{Uri=$u;Method=$m;WebSession=$session;Headers=@{Accept='application/json'}}
  if($null -ne $body){$args.ContentType='application/json';$args.Body=($body|ConvertTo-Json -Depth 10)}
  $r=Invoke-WebRequest @args
  [pscustomobject]@{Status=$r.StatusCode;Json=($r.Content|ConvertFrom-Json);Raw=$r.Content}
}
$login=J "$base/api/gateway/staff/cashier/auth/login" 'POST' @{username='cashier_lan';password='123456'}
$dash=J "$base/api/gateway/staff/cashier/dashboard?branchId=1"
$order = $dash.Json.activeOrders | Where-Object { $_.status -eq 'PENDING' -or $_.status -eq 'CONFIRMED' } | Select-Object -First 1
if(-not $order){ throw 'No pending/confirmed order found on cashier dashboard.' }
$checkoutBody=@{paymentMethod='CASH';amount=[decimal]$order.subtotal;discountAmount=0;loyaltyPointsToRedeem=0;note='rt-full-regression-cash'}
$checkout=J "$base/api/gateway/staff/cashier/orders/$($order.orderId)/checkout" 'POST' $checkoutBody
$history=J "$base/api/gateway/staff/cashier/history?branchId=1&page=1&pageSize=20"
$bill=$history.Json.items | Where-Object { $_.orderId -eq $order.orderId } | Select-Object -First 1
[pscustomobject]@{
  loginStatus=$login.Status
  dashboardStatus=$dash.Status
  orderId=$order.orderId
  orderCode=$order.orderCode
  subtotal=$order.subtotal
  checkoutStatus=$checkout.Status
  checkoutSuccess=$checkout.Json.success
  checkoutMessage=$checkout.Json.message
  historyContainsOrder=($null -ne $bill)
  historyBillCode=if($bill){$bill.billCode}else{$null}
  historyPaymentMethod=if($bill){$bill.paymentMethod}else{$null}
}|ConvertTo-Json -Depth 6
