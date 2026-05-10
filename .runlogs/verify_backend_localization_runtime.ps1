$ErrorActionPreference = 'Stop'

$base = 'http://localhost:5100'
$results = @()

function Add-Result {
    param(
        [string]$Endpoint,
        [int]$Status,
        [string]$Message
    )

    $script:results += [pscustomobject]@{
        endpoint = $Endpoint
        status = $Status
        message = $Message
    }
}

function Add-ErrorResult {
    param(
        [string]$Method,
        [string]$Url,
        [object]$Body = $null,
        [Microsoft.PowerShell.Commands.WebRequestSession]$Session = $null
    )

    try {
        $invokeParams = @{
            Method = $Method
            Uri = $Url
            ErrorAction = 'Stop'
            UseBasicParsing = $true
        }

        if ($Session) {
            $invokeParams.WebSession = $Session
        }

        if ($null -ne $Body) {
            $invokeParams.ContentType = 'application/json'
            $invokeParams.Body = ($Body | ConvertTo-Json -Depth 10)
        }

        Invoke-WebRequest @invokeParams | Out-Null
    }
    catch {
        $response = $_.Exception.Response
        if (-not $response) { throw }

        $reader = [System.IO.StreamReader]::new($response.GetResponseStream())
        $content = $reader.ReadToEnd()
        $payload = $null

        if ($content) {
            try { $payload = $content | ConvertFrom-Json } catch { }
        }

        $message = if ($payload -and $payload.message) { [string]$payload.message } else { [string]$content }
        Add-Result -Endpoint ($Method + ' ' + $Url.Replace($base, '')) -Status ([int]$response.StatusCode) -Message $message
    }
}

$adminSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession

$loginResponse = Invoke-WebRequest `
    -Method Post `
    -Uri ($base + '/api/gateway/admin/auth/login') `
    -WebSession $adminSession `
    -UseBasicParsing `
    -ContentType 'application/json' `
    -Body (@{ username = 'admin'; password = '123456' } | ConvertTo-Json)

Add-Result -Endpoint 'POST /api/gateway/admin/auth/login' -Status ([int]$loginResponse.StatusCode) -Message $null

$name = 'ING_LOC_' + [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()

$createResponse = Invoke-WebRequest `
    -Method Post `
    -Uri ($base + '/api/gateway/admin/ingredients') `
    -WebSession $adminSession `
    -UseBasicParsing `
    -ContentType 'application/json' `
    -Body (@{
        name = $name
        unit = 'gram'
        currentStock = 12
        reorderLevel = 3
        isActive = $true
    } | ConvertTo-Json)

$createPayload = $createResponse.Content | ConvertFrom-Json
Add-Result -Endpoint 'POST /api/gateway/admin/ingredients' -Status ([int]$createResponse.StatusCode) -Message $createPayload.message

$listPayload = Invoke-RestMethod `
    -Method Get `
    -Uri ($base + '/api/gateway/admin/ingredients?search=' + $name + '&page=1&pageSize=20&includeInactive=true') `
    -WebSession $adminSession

$ingredientId = [int]$listPayload.ingredients.items[0].ingredientId

$updateResponse = Invoke-WebRequest `
    -Method Put `
    -Uri ($base + '/api/gateway/admin/ingredients/' + $ingredientId) `
    -WebSession $adminSession `
    -UseBasicParsing `
    -ContentType 'application/json' `
    -Body (@{
        name = $name + '_UPD'
        unit = 'gram'
        currentStock = 15
        reorderLevel = 4
        isActive = $true
    } | ConvertTo-Json)

$updatePayload = $updateResponse.Content | ConvertFrom-Json
Add-Result -Endpoint ('PUT /api/gateway/admin/ingredients/' + $ingredientId) -Status ([int]$updateResponse.StatusCode) -Message $updatePayload.message

$deactivateResponse = Invoke-WebRequest `
    -Method Post `
    -Uri ($base + '/api/gateway/admin/ingredients/' + $ingredientId + '/deactivate') `
    -WebSession $adminSession `
    -UseBasicParsing

$deactivatePayload = $deactivateResponse.Content | ConvertFrom-Json
Add-Result -Endpoint ('POST /api/gateway/admin/ingredients/' + $ingredientId + '/deactivate') -Status ([int]$deactivateResponse.StatusCode) -Message $deactivatePayload.message

$deleteResponse = Invoke-WebRequest `
    -Method Delete `
    -Uri ($base + '/api/gateway/admin/ingredients/' + $ingredientId) `
    -WebSession $adminSession `
    -UseBasicParsing

$deletePayload = $deleteResponse.Content | ConvertFrom-Json
Add-Result -Endpoint ('DELETE /api/gateway/admin/ingredients/' + $ingredientId) -Status ([int]$deleteResponse.StatusCode) -Message $deletePayload.message

Add-ErrorResult -Method 'DELETE' -Url ($base + '/api/gateway/admin/ingredients/29') -Session $adminSession
Add-ErrorResult -Method 'GET' -Url ($base + '/api/gateway/customer/dashboard')
Add-ErrorResult -Method 'GET' -Url ($base + '/api/gateway/customer/branches/0/tables')
Add-ErrorResult -Method 'GET' -Url ($base + '/api/gateway/staff/chef/dashboard')
Add-ErrorResult -Method 'GET' -Url ($base + '/api/gateway/staff/cashier/dashboard')
Add-ErrorResult -Method 'GET' -Url 'http://localhost:5105/api/employees/0/cashier/bills?branchId=1'
Add-ErrorResult -Method 'GET' -Url 'http://localhost:5104/api/internal/customers/loyalty/by-phone'
Add-ErrorResult -Method 'POST' -Url 'http://localhost:5103/api/customers/1/ready-notifications/999999/resolve'

$results | ConvertTo-Json -Depth 6
