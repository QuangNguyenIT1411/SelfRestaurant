$t=Invoke-WebRequest 'http://localhost:5101/api/branches/1/tables' -UseBasicParsing | Select-Object -ExpandProperty Content | ConvertFrom-Json
$t.tables | Select-Object -First 3 | ConvertTo-Json
