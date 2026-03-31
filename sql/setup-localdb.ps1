param(
    [switch]$DropExisting
)

$ErrorActionPreference = "Stop"

$server = "(localdb)\MSSQLLocalDB"
$dbName = "RESTAURANT"
$scriptPath = Join-Path $PSScriptRoot "localdb.sql"
$fallbackScriptPath = Join-Path $PSScriptRoot "sqlchuan.cleaned.sql"

function Get-SqlCmdPath {
    $candidates = @(
        "sqlcmd",
        "C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\SQLCMD.EXE",
        "C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\180\Tools\Binn\SQLCMD.EXE"
    )

    foreach ($candidate in $candidates) {
        try {
            $command = Get-Command $candidate -ErrorAction Stop
            return $command.Source
        }
        catch {
            if (Test-Path $candidate) {
                return $candidate
            }
        }
    }

    throw "sqlcmd was not found. Install SQL Server command line tools or update setup-localdb.ps1 with the installed path."
}

function Test-HasNullByte {
    param([string]$Path)

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    return $bytes -contains 0
}

if (!(Test-Path $scriptPath)) {
    if (Test-Path $fallbackScriptPath) {
        $scriptPath = $fallbackScriptPath
    }
    else {
        throw "Missing script: $scriptPath"
    }
}

if (Test-HasNullByte -Path $scriptPath) {
    if (Test-Path $fallbackScriptPath) {
        Write-Host "Detected NUL bytes in $scriptPath. Using fallback script $fallbackScriptPath"
        $scriptPath = $fallbackScriptPath
    }
    else {
        throw "SQL script contains invalid NUL bytes and no fallback exists: $scriptPath"
    }
}

if ($DropExisting) {
    & (Get-SqlCmdPath) -S $server -E -Q "IF DB_ID('$dbName') IS NOT NULL BEGIN ALTER DATABASE [$dbName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$dbName]; END"
}

& (Get-SqlCmdPath) -S $server -E -Q "IF DB_ID('$dbName') IS NULL CREATE DATABASE [$dbName];"
& (Get-SqlCmdPath) -S $server -E -i $scriptPath -b
& (Join-Path $PSScriptRoot "setup-service-db-shells.ps1") -Server $server -MasterDatabase $dbName

Write-Host "OK: $dbName is ready on $server"
