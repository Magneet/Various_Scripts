$hvServer1 = Connect-HVServer -Server CONNECTIONSERVER
$Services1= $hvServer1.ExtensionData
$queryService = New-Object VMware.Hv.QueryServiceService
$offset=0
$defn = New-Object VMware.Hv.QueryDefinition
$defn.limit= 1000
$defn.maxpagesize = 1000
$defn.queryEntityType = 'MachineNamesView'
$output=@()
do{
$defn.startingoffset = $offset
$QueryResults = $queryService.queryservice_create($Services1, $defn)
if (($QueryResults.results).count -eq 1000){
$maxresults=1
}
else {
    $maxresults=0
}

$offset+=1000
$output+=$queryresults
}
until ($maxresults -eq 0)

($output.results).count
