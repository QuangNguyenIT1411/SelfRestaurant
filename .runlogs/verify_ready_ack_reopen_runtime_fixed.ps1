$base='http://localhost:5100'
function J($m,$u,$s,$b=$null){ if($null -eq $b){ Invoke-RestMethod -Method $m -Uri $u -WebSession $s } else { Invoke-RestMethod -Method $m -Uri $u -WebSession $s -ContentType 'application/json' -Body ($b|ConvertTo-Json -Depth 10) } }
$customer = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$chef = New-Object Microsoft.PowerShell.Commands.WebRequestSession
J Post "$base/api/gateway/customer/auth/login" $customer @{ username='lan.nguyen'; password='123456' } | Out-Null
J Post "$base/api/gateway/staff/auth/login" $chef @{ username='chef_hung'; password='123456' } | Out-Null
$chefMenu = J Get "$base/api/gateway/staff/chef/menu" $chef
$branchId = [int]$chefMenu.branchId
$tables = J Get "$base/api/gateway/customer/branches/$branchId/tables" $customer
$table = @($tables.tables | Where-Object { $_.isAvailable } | Select-Object -First 1)[0]
if($null -eq $table){ throw 'No available table for ready-ack verification.' }
J Post "$base/api/gateway/customer/context/table" $customer @{ branchId=$branchId; tableId=[int]$table.tableId } | Out-Null
$menu = J Get "$base/api/gateway/customer/menu" $customer
$dish = $null
foreach($cat in @($menu.menu.categories)){ foreach($d in @($cat.dishes)){ if($d.available){ $dish=$d; break } }; if($null -ne $dish){ break } }
$add = J Post "$base/api/gateway/customer/order/items" $customer @{ dishId=[int]$dish.dishId; quantity=1; note='READY_ACK_VERIFY' }
$idem = [guid]::NewGuid().ToString('N')
$submit = J Post "$base/api/gateway/customer/order/submit" $customer @{ idempotencyKey=$idem }
$orderId = [int]$submit.orderId
$chefOrders = J Get "$base/api/gateway/staff/chef/dashboard" $chef
$target = @($chefOrders.activeOrders | Where-Object { [int]$_.orderId -eq $orderId } | Select-Object -First 1)[0]
$item = @($target.items | Select-Object -First 1)[0]
J Post "$base/api/gateway/staff/chef/orders/$orderId/items/$($item.itemId)/start" $chef @{} | Out-Null
J Post "$base/api/gateway/staff/chef/orders/$orderId/items/$($item.itemId)/ready" $chef @{} | Out-Null
$ready = J Get "$base/api/gateway/customer/ready-notifications" $customer
$notification = @($ready.notifications | Where-Object { [int]$_.orderId -eq $orderId } | Select-Object -First 1)[0]
J Post "$base/api/gateway/customer/order/confirm-received" $customer @{ orderId=$orderId; notificationId=[long]$notification.notificationId } | Out-Null
$readyAfter = J Get "$base/api/gateway/customer/ready-notifications" $customer
$sessionAfter = J Get "$base/api/gateway/customer/session" $customer
[pscustomobject]@{ orderId=$orderId; notificationId=[long]$notification.notificationId; readyCountBefore=@($ready.notifications).Count; readyCountAfter=@($readyAfter.notifications).Count; sessionTableId=$sessionAfter.tableContext.tableId } | ConvertTo-Json -Depth 10
