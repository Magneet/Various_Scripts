$username="username"
$poolname="Poolname"
$machinename="machinename"
$connectionserver="connectionservername"

$hvserver1=connect-hvserver $connectionserver
$Services1= $hvServer1.ExtensionData

$queryService = New-Object VMware.Hv.QueryServiceService
$defn = New-Object VMware.Hv.QueryDefinition
$defn.queryEntityType = 'ADUserOrGroupSummaryView'
$defn.filter = New-Object VMware.Hv.QueryFilterEquals -property @{'memberName'='base.name'; 'value' = $userName}
try     {
        $userid=($queryService.queryservice_create($Services1, $defn)).results[0].id
        }
catch   { 
        throw "Can't find $Username, exiting" 
        }

add-hvdesktop -poolname $poolname -machines $machinename

start-sleep -s 10

get-hvmachine -machinename $machinename | set-hvmachine -key base.user -Value $userid
