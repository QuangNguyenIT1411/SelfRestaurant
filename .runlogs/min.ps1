$ErrorActionPreference='Stop'
function GetToken([string]$h){$m=[regex]::Match($h,'name="__RequestVerificationToken"\s+type="hidden"\s+value="([^"]+)"');if($m.Success){$m.Groups[1].Value}else{throw 'no token'}}
function Invoke-FormPost($url,$body,$session,$headers=@{}){ Invoke-WebRequest -Uri $url -Method Post -WebSession $session -Body $body -Headers $headers -ContentType 'application/x-www-form-urlencoded' }
$s=New-Object Microsoft.PowerShell.Commands.WebRequestSession
$u='kh'+(Get-Date -Format 'yyyyMMddHHmmss')
$p='Test@123';$e="$u@example.com";$ph='09'+(Get-Random -Minimum 10000000 -Maximum 99999999)
$r=Invoke-WebRequest 'http://localhost:5100/Customer/Register' -WebSession $s -UseBasicParsing
'got page'
$t=GetToken $r.Content
'got token'
$b=@{Name='Khach Test';Username=$u;Password=$p;ConfirmPassword=$p;PhoneNumber=$ph;Email=$e;Gender='Nam';DateOfBirth='2000-01-01';Address='HCM';__RequestVerificationToken=$t}
$r2=Invoke-FormPost 'http://localhost:5100/Customer/Register' $b $s
'after post'
$r2 | Get-Member | Select-Object -First 5
"status=$($r2.StatusCode)"
