$ErrorActionPreference = "Stop"
$html = (Invoke-WebRequest -UseBasicParsing -Uri "http://localhost:5100/app/customer/").Content
[regex]::Matches($html, 'assets/index-[^"\'' ]+\.js') | ForEach-Object { $_.Value }
