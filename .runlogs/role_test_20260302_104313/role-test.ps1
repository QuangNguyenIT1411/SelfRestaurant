$ErrorActionPreference = "Stop"
$base = "http://localhost:5100"

function Invoke-HttpNoRedirect {
    param(
        [Parameter(Mandatory=$true)][string]$Url,
        [Parameter(Mandatory=$true)][Microsoft.PowerShell.Commands.WebRequestSession]$Session,
        [string]$Method = "GET",
        [hashtable]$Body
    )

    try {
        if ($Method -eq "POST") {
            $resp = Invoke-WebRequest -Uri $Url -Method Post -WebSession $Session -Body $Body -MaximumRedirection 0 -UseBasicParsing -ErrorAction Stop
        }
        else {
            $resp = Invoke-WebRequest -Uri $Url -Method Get -WebSession $Session -MaximumRedirection 0 -UseBasicParsing -ErrorAction Stop
        }

        return [pscustomobject]@{
            StatusCode = [int]$resp.StatusCode
            Location   = $resp.Headers["Location"]
        }
    }
    catch {
        if ($_.Exception.Response -ne $null) {
            return [pscustomobject]@{
                StatusCode = [int]$_.Exception.Response.StatusCode.value__
                Location   = $_.Exception.Response.Headers["Location"]
            }
        }

        return [pscustomobject]@{
            StatusCode = -1
            Location   = $_.Exception.Message
        }
    }
}

function Test-StaffLogin {
    param(
        [string]$Role,
        [string]$Username,
        [string]$Password,
        [string]$ExpectedPath,
        [string[]]$Pages
    )

    $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    $loginPage = Invoke-WebRequest -Uri "$base/Staff/Account/Login" -WebSession $session -UseBasicParsing
    $tokenMatch = [regex]::Match($loginPage.Content, 'name="__RequestVerificationToken"\s+type="hidden"\s+value="([^"]+)"')
    if (-not $tokenMatch.Success) {
        Write-Output "LOGIN $Role token_missing"
        return
    }

    $token = $tokenMatch.Groups[1].Value
    $post = Invoke-HttpNoRedirect -Url "$base/Staff/Account/Login" -Method "POST" -Session $session -Body @{
        __RequestVerificationToken = $token
        username = $Username
        password = $Password
        rememberMe = "false"
    }

    Write-Output ("LOGIN {0} status={1} location={2}" -f $Role, $post.StatusCode, $post.Location)

    $expected = Invoke-HttpNoRedirect -Url ("$base" + $ExpectedPath) -Session $session
    Write-Output ("PAGE {0} {1} {2}" -f $Role, $ExpectedPath, $expected.StatusCode)

    foreach ($p in $Pages) {
        $res = Invoke-HttpNoRedirect -Url ("$base" + $p) -Session $session
        Write-Output ("PAGE {0} {1} {2}" -f $Role, $p, $res.StatusCode)
    }
}

Test-StaffLogin -Role "admin" -Username "admin" -Password "123456" -ExpectedPath "/Admin/Dashboard" -Pages @(
    "/Admin/Employees",
    "/Admin/Customers",
    "/Admin/Ingredients",
    "/Admin/Dishes",
    "/Admin/Tables"
)

Test-StaffLogin -Role "cashier" -Username "cashier_lan" -Password "123456" -ExpectedPath "/Staff/Cashier" -Pages @(
    "/Staff/Cashier",
    "/Staff/Cashier/History",
    "/Staff/Cashier/Report"
)

Test-StaffLogin -Role "chef" -Username "chef_hung" -Password "123456" -ExpectedPath "/Staff/Chef" -Pages @(
    "/Staff/Chef",
    "/Staff/Chef/History"
)
