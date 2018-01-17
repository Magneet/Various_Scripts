#-------------------------------------------------
# Linked Clone Configure multiple vlan's
# This script is created to allow a Linked Clone
# Desktop pool to use multiple vlan's
#
# In the past only the 'old' View PowerCLI on the Connection
# broker could be used to accomplish this. Now it's possible 
# from any system running PowerCLI 6.5 or above.
#
# This version replaces all current settings!
# 
# Requires PowerCLI 6.5 or higher
#
# Feel free to use or alter in anyway but please remember the original creator :)
#
# Version 1.0
# 16-01-2018
# Created by: Wouter Kursten
# https://www.retouw.nl
# Twitter @Magneet_NL
#-------------------------------------------------

#Variables

$poolname='Poolname'
$domain='domain'
$username='username'
$password='Mpassword'
$connectionserver='connectionserver'
$maxlabels='5'
# Use a * as wildcard i.e. "DV*"
$labelfilter="DVLAB_Internal*"

#editing below here is on your own risk
$hvserver1=connect-hvserver $connectionserver -domain $domain -username $username -password $password -WarningAction silentlyContinue -erroraction stop
$Services1= $hvServer1.ExtensionData
$queryService = New-Object VMware.Hv.QueryServiceService
$defn = New-Object VMware.Hv.QueryDefinition
$defn.queryEntityType = 'DesktopSummaryView'
$defn.filter = New-Object VMware.Hv.QueryFilterEquals -property @{'memberName'='desktopSummaryData.name'; 'value' = $poolname}
try     {
        $poolid=($queryService.queryservice_create($Services1, $defn)).results
        }
catch   { 
        throw "Can't find $poolname, exiting" 
        }

$pool=$Services1.Desktop.desktop_get($poolid.id)
$networklabelsall=$services1.networklabel.NetworkLabel_ListByHostOrCluster($pool.AutomatedDesktopData.VirtualCenterProvisioningSettings.VirtualCenterProvisioningData.hostorcluster)
$networklabels=$networklabelsall | where-object {$_.data.name -like $labelfilter}
$NetworkInterfaceCard=$services1.NetworkInterfaceCard.NetworkInterfaceCard_ListBySnapshot($pool.AutomatedDesktopData.VirtualCenterProvisioningSettings.VirtualCenterProvisioningData.snapshot)
$NetworkInterfaceCardSettings=new-object vmware.hv.desktopNetworkInterfaceCardSettings
$NetworkInterfaceCardSettings.nic=$NetworkInterfaceCard.id
$networkLabelAssignmentSpecs=@()

foreach ($networklabel in $networklabels){
    $NetworkLabelAssignmentSpec=new-object VMware.Hv.desktopNetworkLabelAssignmentSpec
    $NetworkLabelAssignmentSpec.enabled=$True
    $NetworkLabelAssignmentSpec.networklabel=$networklabel.id
    $NetworkLabelAssignmentSpec.maxlabeltype="LIMITED"
    $NetworkLabelAssignmentSpec.MaxLabel='maxlabels'
    $networkLabelAssignmentSpecs+=$networkLabelAssignmentSpec
    }
$NetworkInterfaceCardSettings.networkLabelAssignmentSpecs=$networkLabelAssignmentSpecs

$VirtualCenterNetworkingSettings=@()
$VirtualCenterNetworkingSettings=new-object vmware.hv.DesktopVirtualCenterNetworkingSettings
$VirtualCenterNetworkingSettings.nics+=$NetworkInterfaceCardSettings

$desktopService = New-Object VMware.Hv.DesktopService
$desktopInfoHelper = $desktopService.read($services1, $Pool.Id)
$desktopinfohelper.getAutomatedDesktopDataHelper().getVirtualCenterProvisioningSettingsHelper().setVirtualCenterNetworkingSettingsHelper($VirtualCenterNetworkingSettings)
$desktopservice.update($services1, $desktopInfoHelper)
