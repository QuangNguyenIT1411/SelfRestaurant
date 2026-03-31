$ErrorActionPreference='Stop'
$base='http://localhost:5100'
$s=New-Object Microsoft.PowerShell.Commands.WebRequestSession

# login
$lp=Invoke-WebRequest "$base/Customer/Login?mode=login&force=true" -WebSession $s -UseBasicParsing
$tok=[regex]::Match($lp.Content,'name="__RequestVerificationToken"[^>]*value="([^"]+)"').Groups[1].Value
$lr=Invoke-WebRequest "$base/Customer/Login" -Method Post -WebSession $s -UseBasicParsing -Headers @{ 'X-Requested-With'='XMLHttpRequest'} -Body @{
  __RequestVerificationToken=$tok
  mode='login'
  'Login.Username'='lan.nguyen'
  'Login.Password'='123456'
  'Login.ReturnUrl'=''
}
$lj=$lr.Content|ConvertFrom-Json
if(-not $lj.success){ throw "Login failed: $($lr.Content)" }

# enter menu to set current table
$null=Invoke-WebRequest "$base/Menu?tableId=2&BranchId=1" -WebSession $s -UseBasicParsing

# open home and post ResetTable form with antiforgery token from page
$homePage=Invoke-WebRequest "$base/" -WebSession $s -UseBasicParsing
$ft=[regex]::Match($homePage.Content,'name="__RequestVerificationToken"[^>]*value="([^"]+)"').Groups[1].Value
if([string]::IsNullOrWhiteSpace($ft)){ throw 'No antiforgery token on Home reset form' }

$reset=Invoke-WebRequest "$base/Menu/ResetTable" -Method Post -WebSession $s -UseBasicParsing -MaximumRedirection 0 -ErrorAction SilentlyContinue -ContentType 'application/x-www-form-urlencoded' -Body @{
  __RequestVerificationToken=$ft
  tableId=2
  BranchId=1
}

if($reset -eq $null){
  throw 'Reset request returned null'
}

"RESET_STATUS=$($reset.StatusCode)"
"RESET_LOCATION=$($reset.Headers['Location'])"
