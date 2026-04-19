$base = 'http://localhost:5110'
$username = 'phase2_0410134014'
$result = Invoke-RestMethod -Uri "$base/api/gateway/customer/auth/forgot-password" -Method Post -ContentType 'application/json' -Body (@{ usernameOrEmailOrPhone = $username } | ConvertTo-Json)
$result | ConvertTo-Json -Depth 5
