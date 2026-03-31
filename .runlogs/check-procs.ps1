Get-Process | Where-Object { $_.ProcessName -like 'SelfRestaurant*' -or $_.ProcessName -eq 'dotnet' } |
  Select-Object ProcessName, Id, CPU |
  Sort-Object ProcessName |
  Format-Table -AutoSize
