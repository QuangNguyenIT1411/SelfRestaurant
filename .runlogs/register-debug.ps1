$ErrorActionPreference='Stop'
function GetToken([string]$h){$m=[regex]::Match($h,'name="__RequestVerificationToken"\s+type="hidden"\s+value="([^"]+)"');if($m.Success){$m.Groups[1].Value}else{throw 'no token'}}
$s=New-Object Microsoft.PowerShell.Commands.WebRequestSession
$u='kh'+(Get-Date -Format 'yyyyMMddHHmmss')
$p='Test@123';$e="$u@example.com";$ph='09'+(Get-Random -Minimum 10000000 -Maximum 99999999)
$r=Invoke-WebRequest 'http://localhost:5100/Customer/Register' -WebSession $s -UseBasicParsing
$t=GetToken $r.Content
$b=@{Name='Khach Test';Username=$u;Password=$p;ConfirmPassword=$p;PhoneNumber=$ph;Email=$e;Gender='Nam';DateOfBirth='2000-01-01';Address='HCM';__RequestVerificationToken=$t}
try{
  $r2=Invoke-WebRequest 'http://localhost:5100/Customer/Register' -Method Post -WebSession $s -Body $b -ContentType 'application/x-www-form-urlencoded' -UseBasicParsing
  "OK status=$($r2.StatusCode)"
}catch{
  "ERR msg=$($_.Exception.Message)"
  if($_.Exception.Response){
    $resp=$_.Exception.Response
    "HTTP status=" + [int]$resp.StatusCode
    $sr=New-Object System.IO.StreamReader($resp.GetResponseStream())
    $body=$sr.ReadToEnd()
    $sr.Close()
    $body.Substring(0,[Math]::Min(1200,$body.Length))
  }
}
