$ErrorActionPreference = 'Stop'
$root = (Get-Location).Path
$out = Join-Path $root '.runlogs\build_full.out.log'
$err = Join-Path $root '.runlogs\build_full.err.log'
if(Test-Path $out){ Remove-Item $out -Force }
if(Test-Path $err){ Remove-Item $err -Force }
$dotnet = 'C:\Program Files\dotnet\dotnet.exe'
$p = Start-Process -FilePath $dotnet -ArgumentList @('build','SelfRestaurant.Microservices.sln','-c','Release') -WorkingDirectory $root -RedirectStandardOutput $out -RedirectStandardError $err -PassThru -Wait -NoNewWindow
Write-Host "exit=$($p.ExitCode)"
Write-Host "out=$out"
Write-Host "err=$err"
