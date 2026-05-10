$ErrorActionPreference='Stop'
[Console]::OutputEncoding=[System.Text.Encoding]::UTF8
try {
  Invoke-WebRequest -Uri 'http://localhost:5100/api/gateway/customer/dashboard' -Headers @{Accept='application/json'} | Out-Null
} catch {
  $resp = $_.Exception.Response
  $stream = $resp.GetResponseStream()
  $ms = New-Object System.IO.MemoryStream
  $stream.CopyTo($ms)
  $bytes = $ms.ToArray()
  $utf8 = [System.Text.Encoding]::UTF8.GetString($bytes)
  [pscustomobject]@{
    Status = [int]$resp.StatusCode
    HexSample = (($bytes | Select-Object -First 80 | ForEach-Object { $_.ToString('X2') }) -join ' ')
    Utf8 = $utf8
  } | ConvertTo-Json -Depth 4
}
