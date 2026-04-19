$ErrorActionPreference = 'Stop'
$base = 'http://localhost:5100'
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$stamp = Get-Date -Format 'MMddHHmmss'
$username = "phase2_$stamp"
$phone = "09$((Get-Random -Minimum 10000000 -Maximum 99999999))"
$password = 'Pass@123'
$newPassword = 'Pass@456'

$branches = Invoke-RestMethod -Uri "$base/api/gateway/customer/branches" -WebSession $session -Method Get
$branchId = $branches[0].branchId
$tables = Invoke-RestMethod -Uri "$base/api/gateway/customer/branches/$branchId/tables" -WebSession $session -Method Get
$table = $tables.tables[0]
Invoke-RestMethod -Uri "$base/api/gateway/customer/context/table" -WebSession $session -Method Post -ContentType 'application/json' -Body (@{ tableId = $table.tableId; branchId = $table.branchId } | ConvertTo-Json) | Out-Null
Invoke-RestMethod -Uri "$base/api/gateway/customer/auth/register" -WebSession $session -Method Post -ContentType 'application/json' -Body (@{ name = 'Phase2 Test'; username = $username; password = $password; phoneNumber = $phone; email = "$username@example.com"; gender='Nam'; address='HCM' } | ConvertTo-Json) | Out-Null
Invoke-RestMethod -Uri "$base/api/gateway/customer/auth/login" -WebSession $session -Method Post -ContentType 'application/json' -Body (@{ username = $username; password = $password } | ConvertTo-Json) | Out-Null
$profile = Invoke-RestMethod -Uri "$base/api/gateway/customer/profile" -WebSession $session -Method Get
$updatedProfile = Invoke-RestMethod -Uri "$base/api/gateway/customer/profile" -WebSession $session -Method Put -ContentType 'application/json' -Body (@{ username = $username; name='Phase2 Updated'; phoneNumber=$phone; email="$username@example.com"; gender='Nam'; dateOfBirth='2000-01-01'; address='Updated Address' } | ConvertTo-Json)
$history = Invoke-RestMethod -Uri "$base/api/gateway/customer/orders/history?take=5" -WebSession $session -Method Get
$notifications = Invoke-RestMethod -Uri "$base/api/gateway/customer/ready-notifications" -WebSession $session -Method Get
$changePassword = Invoke-RestMethod -Uri "$base/api/gateway/customer/auth/change-password" -WebSession $session -Method Post -ContentType 'application/json' -Body (@{ currentPassword=$password; newPassword=$newPassword; confirmPassword=$newPassword } | ConvertTo-Json)
$forgot = Invoke-RestMethod -Uri "$base/api/gateway/customer/auth/forgot-password" -Method Post -ContentType 'application/json' -Body (@{ usernameOrEmailOrPhone = $username } | ConvertTo-Json)
$resetSummary = $null
if ($forgot.resetToken) {
  $resetSummary = Invoke-RestMethod -Uri "$base/api/gateway/customer/auth/reset-password" -Method Post -ContentType 'application/json' -Body (@{ token=$forgot.resetToken; newPassword=$password; confirmPassword=$password } | ConvertTo-Json)
}
[pscustomobject]@{
  Username = $username
  BranchId = $branchId
  TableId = $table.tableId
  ProfileName = $profile.name
  UpdatedAddress = $updatedProfile.address
  HistoryCount = @($history).Count
  NotificationCount = @($notifications.items).Count
  ChangePassword = $changePassword.message
  ForgotMessage = $forgot.message
  ResetWorked = [bool]$resetSummary
} | ConvertTo-Json -Depth 5
