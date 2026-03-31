$r=Invoke-WebRequest 'http://localhost:5101/api/admin/dishes/12' -UseBasicParsing
Write-Output $r.Content
