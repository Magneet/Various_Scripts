function get-adusersorgroupssummaryview{
    $queryService = New-Object VMware.Hv.QueryServiceService
    $offset=0
    $defn = New-Object VMware.Hv.QueryDefinition
    $defn.limit= 1000
    $defn.maxpagesize = 1000
    $defn.queryEntityType = 'ADUserOrGroupSummaryView'
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
    return $output.results
    }
    $vcenter=$services1.virtualcenter.virtualcenter_list()
    $vmlist=$services1.virtualmachine.virtualmachine_list($vcenter.id)
    $vm=$vmlist | where {$_.name -like "VMNAME"}

$pool=(get-hvpool | where {$_.base.name -like "POOLNAME" }).id
$pool.manualdesktopdata.userassignment
$adcontent=get-adusersorgroupssummaryview
$SpecifiedName= new-object VMware.Hv.DesktopSpecifiedName
$SpecifiedName.vmName="$vm.name"
$SpecifiedName.user=($adcontent | where {$_.base.name -like "USERNAME"}).id

#$services1.desktop.desktop_addmachinetomanualdesktop($poolid, $vm.id)
#$services1.userentitlement.userentitlement_create($UserEntitlementBase)
$services1.desktop.Desktop_AddMachineToSpecifiedNamingDesktop($pool, $SpecifiedName)
