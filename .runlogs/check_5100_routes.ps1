$urls = @(
  'http://localhost:5100/app/customer',
  'http://localhost:5100/app/chef',
  'http://localhost:5100/app/cashier',
  'http://localhost:5100/app/admin',
  'http://localhost:5100/api/gateway/customer/session'
)
foreach ($u in $urls) {
  try {
    $r = Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 20
    Write-Output ($u + ' => ' + $r.StatusCode + ' ' + $r.Headers['Content-Type'])
  }
  catch {
    Write-Output ($u + ' => ERROR ' + $_.Exception.Message)
  }
}
