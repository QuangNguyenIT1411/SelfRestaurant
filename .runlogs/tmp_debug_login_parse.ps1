$ErrorActionPreference='Stop'
function Get-Token([string]$html){
  $p='name="__RequestVerificationToken"[^>]*value="([^"]+)"'
  $m=[regex]::Match($html,$p,[System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  if($m.Success){return $m.Groups[1].Value}
  throw 'no token'
}
function To-JsonObj($response) {
  $content = if ($null -eq $response.Content) { '' } else { [string]$response.Content }
  $content = $content.Trim()
  if ([string]::IsNullOrWhiteSpace($content)) {
      return [pscustomobject]@{ success = $false; raw = '' }
  }
  $candidates = @($content)
  $start = $content.IndexOf('{')
  $end = $content.LastIndexOf('}')
  if ($start -ge 0 -and $end -gt $start) {
      $slice = $content.Substring($start, $end - $start + 1)
      if ($slice -ne $content) { $candidates += $slice }
  }
  foreach ($candidate in $candidates) {
      try { return ($candidate | ConvertFrom-Json -Depth 30) } catch { Write-Output ('parse_fail='+$_.Exception.Message) }
  }
  return [pscustomobject]@{ success = $false; raw = $content }
}
function Get-PropValue {
  param([object]$Object,[string[]]$CandidateNames)
  foreach($name in $CandidateNames){
    $prop=$Object.PSObject.Properties | Where-Object { $_.Name -ieq $name } | Select-Object -First 1
    if($null -ne $prop){ return $prop.Value }
  }
  return $null
}
$s=New-Object Microsoft.PowerShell.Commands.WebRequestSession
$lp=Invoke-WebRequest 'http://localhost:5100/Customer/Login?mode=login&force=true' -WebSession $s -UseBasicParsing
$t=Get-Token $lp.Content
$r=Invoke-WebRequest 'http://localhost:5100/Customer/Login' -Method Post -WebSession $s -UseBasicParsing -Headers @{ 'X-Requested-With'='XMLHttpRequest' } -Body @{__RequestVerificationToken=$t;mode='login';'Login.Username'='lan.nguyen';'Login.Password'='123456';'Login.ReturnUrl'=''}
Write-Output ('raw=['+$r.Content+']')
$j=To-JsonObj $r
Write-Output ('type=' + $j.GetType().FullName)
$ok=Get-PropValue -Object $j -CandidateNames @('success','Success')
Write-Output ('ok_type=' + ($ok.GetType().FullName))
Write-Output ('ok=' + $ok)
