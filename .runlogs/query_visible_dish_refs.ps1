$base='http://localhost:5100'
$customer = New-Object Microsoft.PowerShell.Commands.WebRequestSession
Invoke-RestMethod -Method Post -Uri "$base/api/gateway/customer/auth/login" -WebSession $customer -ContentType 'application/json' -Body (@{username='lan.nguyen';password='123456'}|ConvertTo-Json) | Out-Null
Invoke-RestMethod -Method Post -Uri "$base/api/gateway/customer/context/table" -WebSession $customer -ContentType 'application/json' -Body (@{branchId=1;tableId=18}|ConvertTo-Json) | Out-Null
$menu = Invoke-RestMethod -Method Get -Uri "$base/api/gateway/customer/menu" -WebSession $customer
foreach($dish in ($menu.categories | ForEach-Object { $_.dishes })){
  $ref = Invoke-RestMethod -Method Get -Uri ("http://localhost:5102/api/internal/dishes/" + $dish.dishId + "/references")
  Write-Output ($dish.dishId.ToString() + '|' + $dish.name + '|' + $dish.available + '|' + $ref.orderItemCount)
}
