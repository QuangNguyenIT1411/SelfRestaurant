$ErrorActionPreference='Stop'
function Tok([string]$h){$p='name="__RequestVerificationToken"\s+type="hidden"\s+value="([^"]+)"';$m=[regex]::Match($h,$p);if($m.Success){$m.Groups[1].Value}else{throw 'no token'}}
$s=New-Object Microsoft.PowerShell.Commands.WebRequestSession
$u='kh20260301093041';$cur='Test@456';$new='Test@789'
# login
$l=Invoke-WebRequest 'http://localhost:5100/Customer/Login?force=true' -WebSession $s -UseBasicParsing
$t=Tok $l.Content
$lb=@{Username=$u;Password=$cur;RememberMe='false';ReturnUrl='';__RequestVerificationToken=$t}
$l2=Invoke-WebRequest 'http://localhost:5100/Customer/Login' -Method Post -WebSession $s -Body $lb -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing
"loginStatus=$($l2.StatusCode)"
# change password
$d=Invoke-WebRequest 'http://localhost:5100/Customer/Dashboard' -WebSession $s -UseBasicParsing
$dt=Tok $d.Content
$cb=@{currentPassword=$cur;newPassword=$new;confirmPassword=$new;__RequestVerificationToken=$dt}
$c=Invoke-WebRequest 'http://localhost:5100/Customer/ChangePassword' -Method Post -WebSession $s -Body $cb -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing
"changePasswordStatus=$($c.StatusCode)"
# login with new
$l3=Invoke-WebRequest 'http://localhost:5100/Customer/Login?force=true' -WebSession $s -UseBasicParsing
$t3=Tok $l3.Content
$lb3=@{Username=$u;Password=$new;RememberMe='false';ReturnUrl='';__RequestVerificationToken=$t3}
$l4=Invoke-WebRequest 'http://localhost:5100/Customer/Login' -Method Post -WebSession $s -Body $lb3 -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing
"reloginNewStatus=$($l4.StatusCode)"
# from qr
$q=Invoke-WebRequest 'http://localhost:5100/Menu/FromQr?code=CODEx-TB-TEST' -WebSession $s -UseBasicParsing
"fromQrStatus=$($q.StatusCode)"
if($q.Content -match 'Thực Đơn|Self Restaurant'){ 'fromQrPage=OK' } else { 'fromQrPage=Unknown' }
