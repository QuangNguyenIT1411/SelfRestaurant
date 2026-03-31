Get-Process |
  Where-Object { $_.ProcessName -match 'SelfRestaurant|dotnet' } |
  Select-Object Id,ProcessName,Path |
  Sort-Object ProcessName |
  Format-Table -Auto
