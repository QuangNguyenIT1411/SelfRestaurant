$r=Invoke-WebRequest 'http://localhost:5100/Customer/Login?mode=login&force=true' -UseBasicParsing
function Tok([string]$h){$m=[regex]::Match($h,'name="__RequestVerificationToken"[^>]*value="([^"]+)"');$m.Groups[1].Value}
$t=Tok $r.Content
$s=New-Object Microsoft.PowerShell.Commands.WebRequestSession
$lp=Invoke-WebRequest 'http://localhost:5100/Customer/Login?mode=login&force=true' -WebSession $s -UseBasicParsing
$t=Tok $lp.Content
$res=Invoke-WebRequest 'http://localhost:5100/Customer/Login' -Method Post -WebSession $s -UseBasicParsing -Headers @{ 'X-Requested-With'='XMLHttpRequest' } -Body @{__RequestVerificationToken=$t;mode='login';'Login.Username'='lan.nguyen';'Login.Password'='123456';'Login.ReturnUrl'=''}
$c=[string]$res.Content
$o=$c | ConvertFrom-Json -Depth 30
Write-Output ('parsed_type=' + $o.GetType().FullName)
Write-Output ('len=' + $o.Length)
for($i=0;$i -lt $o.Length;$i++){ Write-Output ('i='+$i+' type='+$o[$i].GetType().FullName+' value='+$o[$i]) }
