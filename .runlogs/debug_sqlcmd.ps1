$ErrorActionPreference = "Stop"
$candidates = @(
    "sqlcmd",
    "C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\SQLCMD.EXE",
    "C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\180\Tools\Binn\SQLCMD.EXE"
)
foreach ($candidate in $candidates) {
    try {
        $command = Get-Command $candidate -ErrorAction Stop
        Write-Output ("FOUND=" + $candidate + " => " + $command.Source)
    }
    catch {
        if (Test-Path $candidate) {
            Write-Output ("PATH=" + $candidate)
        }
        else {
            Write-Output ("MISS=" + $candidate)
        }
    }
}
$sqlcmd = "C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\SQLCMD.EXE"
if (Test-Path $sqlcmd) {
    & $sqlcmd -S "(localdb)\MSSQLLocalDB" -E -Q "SELECT DB_ID('RESTAURANT') AS DbId"
    Write-Output ("EXIT=" + $LASTEXITCODE)
}
