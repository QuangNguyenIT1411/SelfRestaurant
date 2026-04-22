$root='C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main'
$logDir=Join-Path $root '.runlogs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$services=@(
  @{Name='catalog';Exe=Join-Path $root 'src\Services\SelfRestaurant.Catalog.Api\bin\Release\net8.0\SelfRestaurant.Catalog.Api.exe';Url='http://localhost:5101';Env='Production'},
  @{Name='orders';Exe=Join-Path $root 'src\Services\SelfRestaurant.Orders.Api\bin\Release\net8.0\SelfRestaurant.Orders.Api.exe';Url='http://localhost:5102';Env='Production'},
  @{Name='customers';Exe=Join-Path $root 'src\Services\SelfRestaurant.Customers.Api\bin\Release\net8.0\SelfRestaurant.Customers.Api.exe';Url='http://localhost:5103';Env='Production'},
  @{Name='identity';Exe=Join-Path $root 'src\Services\SelfRestaurant.Identity.Api\bin\Release\net8.0\SelfRestaurant.Identity.Api.exe';Url='http://localhost:5104';Env='Development'},
  @{Name='billing';Exe=Join-Path $root 'src\Services\SelfRestaurant.Billing.Api\bin\Release\net8.0\SelfRestaurant.Billing.Api.exe';Url='http://localhost:5105';Env='Production'},
  @{Name='gateway';Exe=Join-Path $root 'src\Gateway\SelfRestaurant.Gateway.Api\bin\Release\net8.0\SelfRestaurant.Gateway.Api.exe';Url='http://localhost:5100';Env='Development'}
)
foreach($svc in $services){
  $wd=Split-Path $svc.Exe -Parent
  $out=Join-Path $logDir ($svc.Name + '.out.log')
  $err=Join-Path $logDir ($svc.Name + '.err.log')
  $psi=New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName=$svc.Exe
  $psi.WorkingDirectory=$wd
  $psi.UseShellExecute=$false
  $psi.RedirectStandardOutput=$true
  $psi.RedirectStandardError=$true
  $psi.Environment['ASPNETCORE_URLS']=$svc.Url
  $psi.Environment['ASPNETCORE_ENVIRONMENT']=$svc.Env
  $psi.Environment['Services__Catalog']='http://localhost:5101'
  $psi.Environment['Services__Orders']='http://localhost:5102'
  $psi.Environment['Services__Customers']='http://localhost:5103'
  $psi.Environment['Services__Identity']='http://localhost:5104'
  $psi.Environment['Services__Billing']='http://localhost:5105'
  if($svc.Name -eq 'gateway'){
    $psi.Environment['Frontend__CustomerDistPath']=Join-Path $root 'src\Frontend\selfrestaurant-customer-web\dist'
    $psi.Environment['Frontend__ChefDistPath']=Join-Path $root 'src\Frontend\selfrestaurant-chef-web\dist'
    $psi.Environment['Frontend__CashierDistPath']=Join-Path $root 'src\Frontend\selfrestaurant-cashier-web\dist'
    $psi.Environment['Frontend__AdminDistPath']=Join-Path $root 'src\Frontend\selfrestaurant-admin-web\dist'
  }
  $p=New-Object System.Diagnostics.Process
  $p.StartInfo=$psi
  $p.Start() | Out-Null
  Start-Sleep -Milliseconds 250
  Start-Job -ScriptBlock { param($proc,$outFile,$errFile) $proc.StandardOutput.ReadToEnd() | Set-Content $outFile; $proc.StandardError.ReadToEnd() | Set-Content $errFile } -ArgumentList $p,$out,$err | Out-Null
  Write-Output ("started {0} pid={1}" -f $svc.Name,$p.Id)
}
