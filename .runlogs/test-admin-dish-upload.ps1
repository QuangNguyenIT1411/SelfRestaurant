$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Net.Http

$base = 'http://localhost:5100'
$adminBase = "$base/api/gateway/admin"
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$repo = 'C:\Users\Quang\Downloads\SINH_VIEN\SINH_VIEN\SelfRestaurant-main'
$stamp = Get-Date -Format 'yyyyMMddHHmmss'
$dishName = "UploadDish$stamp"
$svgPath = Join-Path $env:TEMP "upload-dish-$stamp.svg"
$pngPath = Join-Path $env:TEMP "upload-dish-$stamp.png"
$createdDishId = $null

function Get-ErrorBody {
    param($ErrorRecord)
    $response = $ErrorRecord.Exception.Response
    if ($response -and $response.GetResponseStream()) {
        $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
        return $reader.ReadToEnd()
    }
    return $ErrorRecord.Exception.Message
}

function Invoke-Json {
    param(
        [ValidateSet('GET', 'POST', 'PUT', 'PATCH', 'DELETE')][string]$Method,
        [string]$Uri,
        [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession,
        $Body = $null
    )

    try {
        if ($null -eq $Body) {
            return Invoke-RestMethod -Method $Method -Uri $Uri -WebSession $WebSession -TimeoutSec 60
        }

        $json = $Body | ConvertTo-Json -Depth 20
        $payload = [System.Text.Encoding]::UTF8.GetBytes($json)
        return Invoke-RestMethod -Method $Method -Uri $Uri -WebSession $WebSession -TimeoutSec 60 -ContentType 'application/json; charset=utf-8' -Body $payload
    }
    catch {
        throw (Get-ErrorBody $_)
    }
}

function New-HttpClient {
    param([Microsoft.PowerShell.Commands.WebRequestSession]$WebSession)

    $handler = New-Object System.Net.Http.HttpClientHandler
    $handler.CookieContainer = $WebSession.Cookies
    $handler.UseCookies = $true
    $handler.AllowAutoRedirect = $true
    $client = New-Object System.Net.Http.HttpClient($handler)
    $client.Timeout = [TimeSpan]::FromSeconds(60)
    return $client
}

function Add-StringPart {
    param(
        [System.Net.Http.MultipartFormDataContent]$Content,
        [string]$Name,
        [string]$Value
    )
    $Content.Add((New-Object System.Net.Http.StringContent($Value)), $Name)
}

function Add-FilePart {
    param(
        [System.Net.Http.MultipartFormDataContent]$Content,
        [string]$Name,
        [string]$Path
    )
    $stream = [System.IO.File]::OpenRead($Path)
    $fileContent = New-Object System.Net.Http.StreamContent($stream)
    $contentType = 'image/png'
    if ($Path.ToLowerInvariant().EndsWith('.svg')) {
        $contentType = 'image/svg+xml'
    }
    $fileContent.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse($contentType)
    $Content.Add($fileContent, $Name, [System.IO.Path]::GetFileName($Path))
    return $stream
}

try {
    Invoke-Json POST "$adminBase/auth/login" $session @{
        username = 'admin'
        password = '123456'
    } | Out-Null

    Set-Content -Path $svgPath -Value '<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48"><rect width="48" height="48" fill="#22c55e"/></svg>' -Encoding UTF8
    [System.IO.File]::WriteAllBytes($pngPath, [Convert]::FromBase64String('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aRXcAAAAASUVORK5CYII='))

    $dishesBefore = Invoke-Json GET "$adminBase/dishes?search=$([uri]::EscapeDataString($dishName))" $session
    $categoryId = [int](@($dishesBefore.categories | Select-Object -First 1)[0].categoryId)
    if ($categoryId -le 0) { throw 'Khong tim thay category de tao dish upload.' }

    $client = New-HttpClient $session

    $createContent = New-Object System.Net.Http.MultipartFormDataContent
    Add-StringPart $createContent 'name' $dishName
    Add-StringPart $createContent 'price' '25000'
    Add-StringPart $createContent 'categoryId' ([string]$categoryId)
    Add-StringPart $createContent 'description' 'Trai cay test upload'
    Add-StringPart $createContent 'unit' 'phan'
    Add-StringPart $createContent 'isVegetarian' 'true'
    Add-StringPart $createContent 'isDailySpecial' 'false'
    Add-StringPart $createContent 'available' 'true'
    Add-StringPart $createContent 'isActive' 'true'
    $createStream = Add-FilePart $createContent 'imageFile' $svgPath
    try {
        $createResponse = $client.PostAsync("$adminBase/dishes/upload", $createContent).GetAwaiter().GetResult()
        if (-not $createResponse.IsSuccessStatusCode) {
            throw $createResponse.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        }
    }
    finally {
        $createStream.Dispose()
        $createContent.Dispose()
    }

    $dishesAfterCreate = Invoke-Json GET "$adminBase/dishes?search=$([uri]::EscapeDataString($dishName))" $session
    $dish = @($dishesAfterCreate.dishes.items | Where-Object { $_.name -eq $dishName } | Sort-Object dishId -Descending) | Select-Object -First 1
    if ($null -eq $dish) { throw 'Khong tim thay mon vua tao bang upload.' }
    $createdDishId = [int]$dish.dishId

    $svgUrl = "$base$($dish.image)"
    $svgStatus = (Invoke-WebRequest -Uri $svgUrl -UseBasicParsing -TimeoutSec 30).StatusCode

    $updateContent = New-Object System.Net.Http.MultipartFormDataContent
    Add-StringPart $updateContent 'name' $dishName
    Add-StringPart $updateContent 'price' '26000'
    Add-StringPart $updateContent 'categoryId' ([string]$dish.categoryId)
    Add-StringPart $updateContent 'description' 'Trai cay test replace image'
    Add-StringPart $updateContent 'unit' 'phan'
    Add-StringPart $updateContent 'image' ([string]$dish.image)
    Add-StringPart $updateContent 'isVegetarian' ([string]$dish.isVegetarian).ToLowerInvariant()
    Add-StringPart $updateContent 'isDailySpecial' ([string]$dish.isDailySpecial).ToLowerInvariant()
    Add-StringPart $updateContent 'available' ([string]$dish.available).ToLowerInvariant()
    Add-StringPart $updateContent 'isActive' ([string]$dish.isActive).ToLowerInvariant()
    $updateStream = Add-FilePart $updateContent 'imageFile' $pngPath
    try {
        $updateResponse = $client.PutAsync("$adminBase/dishes/$createdDishId/upload", $updateContent).GetAwaiter().GetResult()
        if (-not $updateResponse.IsSuccessStatusCode) {
            throw $updateResponse.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        }
    }
    finally {
        $updateStream.Dispose()
        $updateContent.Dispose()
        $client.Dispose()
    }

    $dishesAfterUpdate = Invoke-Json GET "$adminBase/dishes?search=$([uri]::EscapeDataString($dishName))" $session
    $updatedDish = @($dishesAfterUpdate.dishes.items | Where-Object { [int]$_.dishId -eq $createdDishId }) | Select-Object -First 1
    if ($null -eq $updatedDish) { throw 'Khong tim thay mon sau khi update upload.' }

    $pngUrl = "$base$($updatedDish.image)"
    $pngStatus = (Invoke-WebRequest -Uri $pngUrl -UseBasicParsing -TimeoutSec 30).StatusCode

    $svgGone = $false
    try {
        Invoke-WebRequest -Uri $svgUrl -UseBasicParsing -TimeoutSec 30 | Out-Null
    }
    catch {
        if ($_.Exception.Response.StatusCode.value__ -eq 404) {
            $svgGone = $true
        }
        else {
            throw
        }
    }

    Invoke-Json POST "$adminBase/dishes/$createdDishId/deactivate" $session @{} | Out-Null
    $createdDishId = $null

    Write-Output (ConvertTo-Json @{
        dishId = $updatedDish.dishId
        svgStatus = $svgStatus
        pngStatus = $pngStatus
        svgDeletedAfterReplace = $svgGone
    } -Compress)

    if (-not ($svgStatus -eq 200 -and $pngStatus -eq 200 -and $svgGone)) {
        throw 'Kiem tra upload/replace image khong dat.'
    }
}
finally {
    try {
        if ($null -ne $createdDishId) {
            Invoke-Json POST "$adminBase/dishes/$createdDishId/deactivate" $session @{} | Out-Null
        }
    } catch {}

    Remove-Item -Path $svgPath -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $pngPath -Force -ErrorAction SilentlyContinue
    try { Invoke-Json POST "$adminBase/auth/logout" $session @{} | Out-Null } catch {}
}
