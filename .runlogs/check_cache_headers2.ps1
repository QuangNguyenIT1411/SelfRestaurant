$urls = @('http://localhost:5100/app/customer','http://localhost:5100/app/customer/index.html')
foreach ($u in $urls) {
  $resp = Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 20
  Write-Output ('URL=' + $u)
  $resp.Headers.GetEnumerator() | Sort-Object Name | ForEach-Object { Write-Output ($_.Name + '=' + $_.Value) }
  Write-Output '---'
}
