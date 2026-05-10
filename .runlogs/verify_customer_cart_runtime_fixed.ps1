$base='http://localhost:5100'
function J($m,$u,$s,$b=$null){ if($null -eq $b){ Invoke-RestMethod -Method $m -Uri $u -WebSession $s } else { Invoke-RestMethod -Method $m -Uri $u -WebSession $s -ContentType 'application/json' -Body ($b|ConvertTo-Json -Depth 10) } }
$s = New-Object Microsoft.PowerShell.Commands.WebRequestSession
J Post "$base/api/gateway/customer/auth/login" $s @{ username='lan.nguyen'; password='123456' } | Out-Null
$branches = J Get "$base/api/gateway/customer/branches" $s
$branch = @($branches | Select-Object -First 1)[0]
$tables = J Get "$base/api/gateway/customer/branches/$($branch.branchId)/tables" $s
$table = @($tables.tables | Where-Object { $_.isAvailable } | Select-Object -First 1)[0]
if($null -eq $table){ $table = @($tables.tables | Select-Object -First 1)[0] }
J Post "$base/api/gateway/customer/context/table" $s @{ branchId=[int]$branch.branchId; tableId=[int]$table.tableId } | Out-Null
$menu = J Get "$base/api/gateway/customer/menu" $s
$dish = $null
foreach($cat in @($menu.menu.categories)){ foreach($d in @($cat.dishes)){ if($d.available){ $dish=$d; break } }; if($null -ne $dish){ break } }
$add = J Post "$base/api/gateway/customer/order/items" $s @{ dishId=[int]$dish.dishId; quantity=1 }
$orderId = [int]$add.orderId
$pendingItem = @($add.items | Where-Object { [int]$_.orderId -eq $orderId -and [int]$_.dishId -eq [int]$dish.dishId } | Select-Object -Last 1)[0]
$updateOk = $true; $removeOk = $true; $afterUpdate = $null; $afterRemove = $null; $updateErr=''; $removeErr=''
try { J Patch "$base/api/gateway/customer/order/items/$($pendingItem.itemId)/quantity" $s @{ quantity=2 } | Out-Null; $afterUpdate = J Get "$base/api/gateway/customer/order/items" $s } catch { $updateOk=$false; $updateErr=$_.Exception.Message }
try { J Delete "$base/api/gateway/customer/order/items/$($pendingItem.itemId)" $s | Out-Null; $afterRemove = J Get "$base/api/gateway/customer/order/items" $s } catch { $removeOk=$false; $removeErr=$_.Exception.Message }
$updatedItem = if($null -ne $afterUpdate){ @($afterUpdate.items | Where-Object { [int]$_.itemId -eq [int]$pendingItem.itemId } | Select-Object -First 1)[0] } else { $null }
$removedExists = if($null -ne $afterRemove){ @($afterRemove.items | Where-Object { [int]$_.itemId -eq [int]$pendingItem.itemId }).Count -gt 0 } else { $true }
[pscustomobject]@{ orderId=$orderId; itemId=[int]$pendingItem.itemId; dishId=[int]$dish.dishId; updateOk=$updateOk; updateError=$updateErr; updatedQuantity=if($null -ne $updatedItem){ [int]$updatedItem.quantity } else { $null }; removeOk=$removeOk; removeError=$removeErr; removedExists=$removedExists } | ConvertTo-Json -Depth 10
