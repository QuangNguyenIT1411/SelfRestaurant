$base='http://localhost:5100'
function J($m,$u,$s,$b=$null){ if($null -eq $b){ Invoke-RestMethod -Method $m -Uri $u -WebSession $s } else { Invoke-RestMethod -Method $m -Uri $u -WebSession $s -ContentType 'application/json' -Body ($b|ConvertTo-Json -Depth 10) } }
$cashier = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$customer = New-Object Microsoft.PowerShell.Commands.WebRequestSession
J Post "$base/api/gateway/staff/auth/login" $cashier @{ username='cashier_mai'; password='123456' } | Out-Null
J Post "$base/api/gateway/customer/auth/login" $customer @{ username='lan.nguyen'; password='123456' } | Out-Null
$branches = J Get "$base/api/gateway/customer/branches" $customer
$branch = @($branches | Select-Object -First 1)[0]
$tables = J Get "$base/api/gateway/customer/branches/$($branch.branchId)/tables" $customer
$table = @($tables.tables | Where-Object { $_.isAvailable } | Select-Object -First 1)[0]
if($null -eq $table){ throw 'No available table for cashier verification.' }
J Post "$base/api/gateway/customer/context/table" $customer @{ branchId=[int]$branch.branchId; tableId=[int]$table.tableId } | Out-Null
$menu = J Get "$base/api/gateway/customer/menu" $customer
$dish = $null
foreach($cat in @($menu.menu.categories)){ foreach($d in @($cat.dishes)){ if($d.available){ $dish=$d; break } }; if($null -ne $dish){ break } }
$add = J Post "$base/api/gateway/customer/order/items" $customer @{ dishId=[int]$dish.dishId; quantity=1 }
$idem = [guid]::NewGuid().ToString('N')
$submit = J Post "$base/api/gateway/customer/order/submit" $customer @{ idempotencyKey=$idem }
$orderId = [int]$submit.orderId
$dashboard = J Get "$base/api/gateway/staff/cashier/dashboard" $cashier
$activeOrder = @($dashboard.activeOrders | Where-Object { [int]$_.orderId -eq $orderId } | Select-Object -First 1)[0]
$checkout = J Post "$base/api/gateway/staff/cashier/orders/$orderId/checkout" $cashier @{ paymentMethod='CASH'; paymentAmount=[decimal]$submit.subtotal; cashReceived=[decimal]$submit.subtotal; note='REG_VERIFY_CASH' }
$history = J Get "$base/api/gateway/staff/cashier/history" $cashier
$bill = @($history.items | Where-Object { $_.orderId -eq $orderId } | Select-Object -First 1)[0]
$index = Invoke-WebRequest -Uri "$base/app/cashier" -UseBasicParsing -WebSession $cashier
$asset = [regex]::Match([string]$index.Content, '/app/cashier/assets/[^"'']+\.js').Value
$css = [regex]::Match([string]$index.Content, '/app/cashier/assets/[^"'']+\.css').Value
$assetText = Invoke-WebRequest -Uri ("$base" + $asset) -UseBasicParsing
$cssText = Invoke-WebRequest -Uri ("$base" + $css) -UseBasicParsing
$qrOrder = @($dashboard.activeOrders | Select-Object -First 1)[0]
$qrPayload = [pscustomobject]@{ bank='BIDV'; account='8830150124'; amount=[decimal]$qrOrder.subtotal; addInfo=("TT " + $qrOrder.orderCode) }
$qrUrl = "https://img.vietqr.io/image/BIDV-8830150124-compact2.png?amount=$([int]$qrPayload.amount)&addInfo=$([uri]::EscapeDataString($qrPayload.addInfo))"
$qrHead = Invoke-WebRequest -Uri $qrUrl -UseBasicParsing
[pscustomobject]@{ dashboardActiveOrders=@($dashboard.activeOrders).Count; targetOrderId=$orderId; dashboardContainsTarget=($null -ne $activeOrder); cashCheckoutBillCode=$checkout.billCode; historyContainsBill=($null -ne $bill); historyPaymentMethod=if($null -ne $bill){$bill.paymentMethod}else{$null}; cashierPageStatus=[int]$index.StatusCode; jsHasQrMarkers=(([string]$assetText.Content -match 'img.vietqr.io/image/') -and ([string]$assetText.Content -match '8830150124')); cssHasHeroLinkFix=([string]$cssText.Content -match '\.cashier-hero \.cashier-link-button'); qrUrl=$qrUrl; qrStatus=[int]$qrHead.StatusCode; qrContentType=$qrHead.Headers['Content-Type'] } | ConvertTo-Json -Depth 10
