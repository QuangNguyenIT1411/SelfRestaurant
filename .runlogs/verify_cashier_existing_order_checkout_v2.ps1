$ErrorActionPreference='Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$base='http://localhost:5100'
$session=New-Object Microsoft.PowerShell.Commands.WebRequestSession
$headers=@{Accept='application/json'}
$loginBody=@{username='cashier_lan';password='123456'} | ConvertTo-Json
$login = Invoke-RestMethod -Uri "$base/api/gateway/staff/cashier/auth/login" -Method Post -WebSession $session -Headers $headers -ContentType 'application/json' -Body $loginBody
$dash = Invoke-RestMethod -Uri "$base/api/gateway/staff/cashier/dashboard?branchId=1" -Method Get -WebSession $session -Headers $headers
$order = $dash.activeOrders | Where-Object { $_.status -in @('PENDING','CONFIRMED') } | Select-Object -First 1
if ($null -eq $order) { throw 'No pending/confirmed order found.' }
$checkoutBody = @{ paymentMethod='CASH'; amount=[decimal]$order.subtotal; discountAmount=0; loyaltyPointsToRedeem=0; note='rt-full-regression-cash' } | ConvertTo-Json
$checkoutResponse = Invoke-WebRequest -Uri "$base/api/gateway/staff/cashier/orders/$($order.orderId)/checkout" -Method Post -WebSession $session -Headers $headers -ContentType 'application/json' -Body $checkoutBody
$checkoutJson = $checkoutResponse.Content | ConvertFrom-Json
$history = Invoke-RestMethod -Uri "$base/api/gateway/staff/cashier/history?branchId=1&page=1&pageSize=20" -Method Get -WebSession $session -Headers $headers
$bill = $history.items | Where-Object { $_.orderId -eq $order.orderId } | Select-Object -First 1
[pscustomobject]@{
  loginSuccess = $login.success
  orderId = $order.orderId
  orderCode = $order.orderCode
  subtotal = $order.subtotal
  checkoutStatus = [int]$checkoutResponse.StatusCode
  checkoutSuccess = $checkoutJson.success
  checkoutMessage = $checkoutJson.message
  historyContainsOrder = ($null -ne $bill)
  historyBillCode = if ($bill) { $bill.billCode } else { $null }
  historyPaymentMethod = if ($bill) { $bill.paymentMethod } else { $null }
} | ConvertTo-Json -Depth 6
