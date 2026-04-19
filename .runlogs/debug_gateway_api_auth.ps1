$ErrorActionPreference = 'Stop'
$base = 'http://localhost:5110'
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$stamp = Get-Date -Format 'MMddHHmmss'
$username = "auth_$stamp"
$phone = "09$((Get-Random -Minimum 10000000 -Maximum 99999999))"
$password = 'Pass@123'
$r1 = Invoke-RestMethod -Uri "$base/api/gateway/customer/auth/register" -WebSession $session -Method Post -ContentType 'application/json' -Body (@{ name='Auth Test'; username=$username; password=$password; phoneNumber=$phone; email="$username@example.com" } | ConvertTo-Json)
$r2 = Invoke-RestMethod -Uri "$base/api/gateway/customer/auth/login" -WebSession $session -Method Post -ContentType 'application/json' -Body (@{ username=$username; password=$password } | ConvertTo-Json)
$r3 = Invoke-RestMethod -Uri "$base/api/gateway/customer/session" -WebSession $session -Method Get
[pscustomobject]@{ Register=$r1; Login=$r2; Session=$r3; CookieCount=$session.Cookies.Count } | ConvertTo-Json -Depth 8
