$ErrorActionPreference='Stop'
function DumpUndefined($name, $html){
  $lines = $html -split "`n"
  Write-Output "=== $name ==="
  for($i=0; $i -lt $lines.Length; $i++){
    if($lines[$i] -match 'undefined'){
      Write-Output ((($i+1).ToString()) + ': ' + $lines[$i].Trim())
    }
  }
}
$homeHtml = (Invoke-WebRequest 'http://localhost:5100/' -UseBasicParsing).Content
DumpUndefined 'Home' $homeHtml
$s = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$lp = Invoke-WebRequest 'http://localhost:5100/Staff/Account/Login' -WebSession $s -UseBasicParsing
$m=[regex]::Match($lp.Content,'name="__RequestVerificationToken"[^>]*value="([^"]+)"')
$tok=$m.Groups[1].Value
Invoke-WebRequest 'http://localhost:5100/Staff/Account/Login' -Method Post -WebSession $s -Body @{ username='cashier_lan'; password='123456'; __RequestVerificationToken=$tok } -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing | Out-Null
$cashHtml = (Invoke-WebRequest 'http://localhost:5100/Staff/Cashier' -WebSession $s -UseBasicParsing).Content
DumpUndefined 'Cashier' $cashHtml
