$ErrorActionPreference='Stop'

function GetToken([string]$h){
  $patterns = @(
    'name="__RequestVerificationToken"\s+type="hidden"\s+value="([^"]+)"',
    'name="__RequestVerificationToken"\s+value="([^"]+)"',
    'value="([^"]+)"\s+name="__RequestVerificationToken"'
  )
  foreach($p in $patterns){
    $m=[regex]::Match($h,$p)
    if($m.Success){ return $m.Groups[1].Value }
  }
  throw 'no token'
}

$s=New-Object Microsoft.PowerShell.Commands.WebRequestSession
$u='kh'+(Get-Date -Format 'yyyyMMddHHmmss')
$p='Test@123'
$e="$u@example.com"
$ph='09'+(Get-Random -Minimum 10000000 -Maximum 99999999)

try{
  $r=Invoke-WebRequest 'http://localhost:5100/Customer/Register' -WebSession $s -UseBasicParsing
  Write-Output "reg page status=$($r.StatusCode)"
  $t=GetToken $r.Content
  Write-Output "reg token len=$($t.Length)"

  $b=@{Name='Khach Test';Username=$u;Password=$p;ConfirmPassword=$p;PhoneNumber=$ph;Email=$e;Gender='Nam';DateOfBirth='2000-01-01';Address='HCM';__RequestVerificationToken=$t}
  $r2=Invoke-WebRequest 'http://localhost:5100/Customer/Register' -Method Post -WebSession $s -Body $b -ContentType 'application/x-www-form-urlencoded'
  Write-Output "reg post status=$($r2.StatusCode) uri=$($r2.BaseResponse.ResponseUri.AbsoluteUri)"

  $r3=Invoke-WebRequest 'http://localhost:5100/Customer/Login?force=true' -WebSession $s -UseBasicParsing
  Write-Output "login page status=$($r3.StatusCode)"
  $t2=GetToken $r3.Content
  Write-Output "login token len=$($t2.Length)"

  $b2=@{Username=$u;Password=$p;RememberMe='false';ReturnUrl='';__RequestVerificationToken=$t2}
  $r4=Invoke-WebRequest 'http://localhost:5100/Customer/Login' -Method Post -WebSession $s -Body $b2 -ContentType 'application/x-www-form-urlencoded'
  Write-Output "login post status=$($r4.StatusCode) uri=$($r4.BaseResponse.ResponseUri.AbsoluteUri)"
}
catch{
  Write-Output 'ERR'
  Write-Output $_.Exception.Message
  Write-Output $_.ScriptStackTrace
}
