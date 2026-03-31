$urls=@('http://localhost:5100/','http://localhost:5101/healthz','http://localhost:5102/healthz','http://localhost:5103/healthz','http://localhost:5104/healthz','http://localhost:5105/healthz')
foreach($u in $urls){
  try {
    $r=Invoke-WebRequest $u -UseBasicParsing -TimeoutSec 8
    Write-Output ("{0} {1}" -f $u, $r.StatusCode)
  } catch {
    Write-Output ("{0} FAIL" -f $u)
  }
}
