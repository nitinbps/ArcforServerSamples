$subid = "" #subscriptionId
Install-Module -Name Az.ResourceGraph
Select-AzSubscription -Subscription $subid


$expiredServers = Search-AzGraph -Query 'resources|where type == "microsoft.hybridcompute/machines"| where properties.status == "Expired"' -Subscription $subid

foreach($servers in $expiredServers) {
    Remove-AzResource -ResourceId $servers.ResourceId -Verbose -Force
}