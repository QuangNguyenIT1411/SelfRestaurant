$ErrorActionPreference='Stop'
[Console]::OutputEncoding=[System.Text.Encoding]::UTF8
$base='http://localhost:5100'
$session=New-Object Microsoft.PowerShell.Commands.WebRequestSession
$headers=@{Accept='application/json'}
$loginBody=@{username='admin';password='123456'} | ConvertTo-Json
$null = Invoke-RestMethod -Uri "$base/api/gateway/admin/auth/login" -Method Post -WebSession $session -Headers $headers -ContentType 'application/json' -Body $loginBody
$stamp = Get-Date -Format 'yyyyMMddHHmmssfff'
$createBody = @{ name = "ING_UTF8_$stamp"; unit = 'kg'; currentStock = 3; reorderLevel = 1; isActive = $true } | ConvertTo-Json
$createResp = Invoke-RestMethod -Uri "$base/api/gateway/admin/ingredients" -Method Post -WebSession $session -Headers $headers -ContentType 'application/json' -Body $createBody
try {
  Invoke-RestMethod -Uri "$base/api/gateway/admin/ingredients/29" -Method Delete -WebSession $session -Headers $headers | Out-Null
} catch {
  $resp = $_.Exception.Response
  $stream = $resp.GetResponseStream()
  $ms = New-Object System.IO.MemoryStream
  $stream.CopyTo($ms)
  $conflictUtf8 = [System.Text.Encoding]::UTF8.GetString($ms.ToArray())
  [pscustomobject]@{
    createMessage = $createResp.message
    deleteConflictBody = $conflictUtf8
  } | ConvertTo-Json -Depth 5
}
