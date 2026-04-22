$ErrorActionPreference='Stop'
$s=New-Object Microsoft.PowerShell.Commands.WebRequestSession
function J($url,$method='Get',$body=$null){
  if($null -ne $body){ return Invoke-RestMethod -Uri $url -Method $method -WebSession $s -ContentType 'application/json' -Body ($body|ConvertTo-Json -Depth 10) }
  return Invoke-RestMethod -Uri $url -Method $method -WebSession $s
}
J 'http://localhost:5100/api/gateway/customer/dev/reset-test-state' 'Post' | Out-Null
$branches=J 'http://localhost:5100/api/gateway/customer/branches'
$tables=J 'http://localhost:5100/api/gateway/customer/branches/1/tables'
$table=$tables.tables | Where-Object { $_.isAvailable } | Select-Object -First 1
$ctx=J 'http://localhost:5100/api/gateway/customer/context/table' 'Post' @{tableId=$table.tableId;branchId=1}
$menu=J 'http://localhost:5100/api/gateway/customer/menu'
[pscustomobject]@{
  BranchCount=@($branches).Count
  TableId=$table.tableId
  MenuCategories=@($menu.menu.categories).Count
  MenuDishes=@($menu.menu.dishes).Count
  Authenticated=$menu.session.authenticated
  TableContextTableId=$menu.tableContext.tableId
} | ConvertTo-Json -Depth 5
