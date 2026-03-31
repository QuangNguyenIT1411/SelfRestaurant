$ErrorActionPreference='Stop'
function Tok([string]$h){
  $ps=@(
    'name="__RequestVerificationToken"[^>]*value="([^"]+)"',
    "name='__RequestVerificationToken'[^>]*value='([^']+)'",
    'value="([^"]+)"[^>]*name="__RequestVerificationToken"'
  )
  foreach($p in $ps){
    $m=[regex]::Match($h,$p,[System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if($m.Success){ return $m.Groups[1].Value }
  }
  return ''
}
$s=New-Object Microsoft.PowerShell.Commands.WebRequestSession
$lp=Invoke-WebRequest 'http://localhost:5100/Staff/Account/Login' -WebSession $s -UseBasicParsing
$lt=Tok $lp.Content
Invoke-WebRequest 'http://localhost:5100/Staff/Account/Login' -Method Post -WebSession $s -UseBasicParsing -Headers @{ 'X-Requested-With'='XMLHttpRequest' } -Body @{ __RequestVerificationToken=$lt; username='chef_hung'; password='123456'; rememberMe='false' } | Out-Null
$p1=Invoke-WebRequest 'http://localhost:5100/Staff/Chef' -WebSession $s -UseBasicParsing
$p2=Invoke-WebRequest 'http://localhost:5100/Staff/Chef/Index' -WebSession $s -UseBasicParsing
Write-Output "CHEF_status=$($p1.StatusCode) len=$($p1.Content.Length)"
Write-Output "INDEX_status=$($p2.StatusCode) len=$($p2.Content.Length)"
Write-Output "CHEF_token=$(Tok $p1.Content)"
Write-Output "INDEX_token=$(Tok $p2.Content)"
$mentions=[regex]::Matches($p2.Content,'__RequestVerificationToken').Count
Write-Output "INDEX_token_mentions=$mentions"
$p2.Content | Out-File -Encoding utf8 .runlogs/debug_chef_index_latest.html
