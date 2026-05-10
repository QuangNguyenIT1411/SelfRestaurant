$base='http://localhost:5100'
$s = New-Object Microsoft.PowerShell.Commands.WebRequestSession
Invoke-RestMethod -Method Post -Uri "$base/api/gateway/customer/auth/login" -WebSession $s -ContentType 'application/json' -Body (@{username='lan.nguyen';password='123456'}|ConvertTo-Json) | Out-Null
$branches = Invoke-RestMethod -Method Get -Uri "$base/api/gateway/customer/branches" -WebSession $s
$result=@()
foreach($b in @($branches)){
  $t = Invoke-RestMethod -Method Get -Uri "$base/api/gateway/customer/branches/$($b.branchId)/tables" -WebSession $s
  $avail = @($t.tables | Where-Object { $_.isAvailable })
  $result += [pscustomobject]@{ branchId=$b.branchId; name=$b.name; availableCount=$avail.Count; firstAvailable=if($avail.Count -gt 0){$avail[0].tableId}else{$null} }
}
$result | ConvertTo-Json -Depth 10
