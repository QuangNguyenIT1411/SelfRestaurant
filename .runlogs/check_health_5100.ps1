$urls = @(
  'http://localhost:5101/healthz',
  'http://localhost:5102/healthz',
  'http://localhost:5103/healthz',
  'http://localhost:5105/healthz',
  'http://localhost:5100/'
)
foreach($u in $urls){
  try {
    $r = Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 5
    Write-Output ("$u => $($r.StatusCode)")
  }
  catch {
    Write-Output ("$u => FAIL $($_.Exception.Message)")
  }
}
