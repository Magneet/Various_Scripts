#-------------------------------------------------
# Linked Clone get vlan configuration
# This script is created to check if a linked clone pool 
# has any configured vlan/portgroup configuration
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

#region variables
$hvservername=Read-host "Which Connection broker do you want to connect to?"
$domain=read-host "Please enter your active directory domain?"
$username=Read-host "Please enter your useraccount"
$password=Read-host -assecurestring "Please enter your password"
$poolname=read-host "What pool to check?"

#endregion

#region Connect to View Connection broker
Import-module vmware.hv.helper
write-host "Connecting to the connection broker" -ForegroundColor Green
try{
    $hvserver1=connect-hvserver $hvservername -domain $domain -username $username -password $password -WarningAction silentlyContinue -erroraction stop
    $Services1= $hvServer1.ExtensionData
}
catch{
    Write-host "Can't connect to the Connection server please check the credentials." -ForegroundColor Red
    exit
}
    
#endregion

#regio gather and display data
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
$labels=($pool.automateddesktopdata.virtualcenterprovisioningsettings.VirtualCenterNetworkingSettings.nics).NetworkLabelAssignmentSpecs
if (!$labels){
    write-output "No configured portgroup(s) or $poolname not found."
}
else{
    $output=@()
    foreach ($label in $labels){
        $output+= New-Object PSObject -Property @{
            "Labelname" = get-hvinternalname $label.networklabel;
            "Enabled" = $label.Enabled;
            "Labeltype" = $label.maxlabeltype;
            "Max_labelcount" = $label.maxlabel;
        }
    }
$output | select-object Labelname,Labeltype,Max_labelcount,enabled
}
