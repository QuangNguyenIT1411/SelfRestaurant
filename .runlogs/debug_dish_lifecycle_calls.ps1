$ErrorActionPreference='Continue'
$base='http://localhost:5100'
function Step($name, $script) {
  Write-Host "STEP: $name"
  try { & $script | ConvertTo-Json -Depth 10; Write-Host 'OK' }
  catch {
    Write-Host $_.Exception.Message
    if ($_.Exception.Response) {
      $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
      Write-Host ($reader.ReadToEnd())
    }
  }
}
$admin = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$chef = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$customer = New-Object Microsoft.PowerShell.Commands.WebRequestSession
Step 'admin login' { Invoke-RestMethod -Method Post -Uri "$base/api/gateway/staff/auth/login" -WebSession $admin -ContentType 'application/json' -Body (@{username='admin';password='123456'}|ConvertTo-Json) }
Step 'chef login' { Invoke-RestMethod -Method Post -Uri "$base/api/gateway/staff/auth/login" -WebSession $chef -ContentType 'application/json' -Body (@{username='chef_hung';password='123456'}|ConvertTo-Json) }
Step 'customer login' { Invoke-RestMethod -Method Post -Uri "$base/api/gateway/customer/auth/login" -WebSession $customer -ContentType 'application/json' -Body (@{username='lan.nguyen';password='123456'}|ConvertTo-Json) }
Step 'chef menu' { Invoke-RestMethod -Method Get -Uri "$base/api/gateway/staff/chef/menu" -WebSession $chef }
Step 'branch tables' { Invoke-RestMethod -Method Get -Uri "$base/api/gateway/customer/branches/1/tables" -WebSession $customer }
Step 'set context' { Invoke-RestMethod -Method Post -Uri "$base/api/gateway/customer/context/table" -WebSession $customer -ContentType 'application/json' -Body (@{branchId=1;tableId=1}|ConvertTo-Json) }
Step 'chef create dish' { Invoke-RestMethod -Method Post -Uri "$base/api/gateway/staff/chef/dishes" -WebSession $chef -ContentType 'application/json' -Body (@{name='DEL_DBG';price=11111;categoryId=1;description='dbg';unit='phan';image=$null;isVegetarian=$false;isDailySpecial=$false;available=$true;isActive=$true}|ConvertTo-Json -Depth 10) }
