<#
    .SYNOPSIS
    Cleans up desktops running on an image that's not the default for a desktop pool

    .DESCRIPTION
    This script uses the Horizon soap api's to pull data about machines inside a desktop pool that are running on a snapshot or base vm that's not currently configiured on the desktop pool. By default it logs off the users but there are options to forcefully logoff the user or delete the machines.

    .EXAMPLE
    .\Horizon_cleanup_old_image.ps1 -Credential $creds -ConnectionServerFQDN pod2cbr1.loft.lab -poolname "Pod02 Pool02" -delete -preview

    .PARAMETER Credential
    Mandatory: Yes
    Type: PSCredential
    Object with credentials for the connection server with domain\username and password

    .PARAMETER ConnectionServerFQDN
    Mandatory: No
    Default: String
    FQDN of the connection server to connect to

    .PARAMETER Poolname
    Mandatory: Yes
    Type: string
    Display name of the Desktop Pool to check

    .PARAMETER Deletedesktops
    Mandatory: No
    Enables the deleteion of the desktops, this includes an attempt to forcefully logoff the users.

    .PARAMETER Forcedlogoff
    Mandatory: No
    Enables the forcefully logging off of the users.

    .PARAMETER Preview
    Mandatory: No
    Makes the script run in preview mode and not undertake any actions.

    .NOTES
    Created by: Wouter Kursten
    First version: 27-06-2021

    .COMPONENT
    VMWare PowerCLI

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$false,
    HelpMessage='Credential object as domain\username with password' )]
    [PSCredential] $Credential,

    [Parameter(Mandatory=$true,  HelpMessage='FQDN of the connectionserver' )]
    [ValidateNotNullOrEmpty()]
    [string] $ConnectionServerFQDN,

    [parameter(Mandatory = $true,
    HelpMessage = "Display Name of the desktop pool to logoff the users.")]
    [string]$poolname = $false,

    [Parameter(Mandatory=$false, 
    HelpMessage='Deletes the desktops instead of forcing the logoff' )]
    [switch] $deletedesktops,

    [Parameter(Mandatory=$false, 
    HelpMessage='Gives a preview only, no action will be undertaken.' )]
    [switch] $preview,

    [Parameter(Mandatory=$false, 
    HelpMessage='Forcefully logs off the users in case the desktop is locked or disconnected.' )]
    [switch] $forcedlogoff
)

if($Credential){
    $creds = $credential
}
else{
    $creds = get-credential
}

$ErrorActionPreference = 'Stop'

# Preview info
if($preview){
    write-host "Running in preview mode no actions will be taken" -foregroundcolor Magenta
}

# Loading powercli modules
Import-Module VMware.VimAutomation.HorizonView
Import-Module VMware.VimAutomation.Core

$hvserver1=connect-hvserver $ConnectionServerFQDN -credential $creds
$Services1= $hvServer1.ExtensionData

# --- Get Services for interacting with the Horizon API Service ---
$Services1= $hvServer1.ExtensionData

# --- Get Desktop pool
$poolqueryservice=new-object vmware.hv.queryserviceservice
$pooldefn = New-Object VMware.Hv.QueryDefinition
$pooldefn.queryentitytype='DesktopSummaryView'
$pooldefn.Filter= New-Object VMware.Hv.QueryFilterEquals -property @{'MemberName'='desktopSummaryData.displayName'; 'value'=$poolname}
try{
    $poolqueryResults = $poolqueryService.QueryService_Create($Services1, $pooldefn) 
    $poolqueryservice.QueryService_DeleteAll($services1)
    $results = $poolqueryResults.results
}
catch{
    write-error "There was an error retreiving details for $poolname"
}

# we need more details of the pool though and check if we even got one
if($results.count -eq 1){
    $pool = $Services1.Desktop.Desktop_Get($results.id)
}
else{
    write-host "No pool found with name $poolname" -foregroundcolor Red
    break
}

# Search for machine details
$queryservice=new-object vmware.hv.queryserviceservice
$defn = New-Object VMware.Hv.QueryDefinition
$defn.queryentitytype='MachineDetailsView'
$defn.filter = New-Object VMware.Hv.QueryFilterEquals -Property @{ 'memberName' = 'desktopData.id'; 'value' = $pool.id }
[array]$queryResults = $queryService.QueryService_Create($Services1, $defn)
$services1.QueryService.QueryService_DeleteAll()
# Process the results
if ($queryResults.results.count -ge 1){
    [array]$poolmachines=$queryResults.results
    [array]$wrongsnaps=$poolmachines | where-object {$_.managedmachinedetailsdata.baseimagesnapshotpath -notlike  $pool.automateddesktopdata.VirtualCenternamesdata.snapshotpath -OR $_.managedmachinedetailsdata.baseimagepath -notlike $pool.automateddesktopdata.VirtualCenternamesdata.parentvmpath}
    # If there are desktops on a wrong snapsot we need to do something with that info
    if($wrongsnaps.count -ge 1){
        if($deletedesktops){
            write-host "Removing:" $wrongsnaps.data.name -foregroundcolor yellow
            $deletespec = new-object vmware.hv.machinedeletespec
            $deletespec.DeleteFromDisk = $true
            $deletespec.ForceLogoffSession = $true
            if(!$preview){
                $Services1.Machine.Machine_DeleteMachines($wrongsnaps.id, $deletespec)
            }
        }
        else{
            write-host "Logging users off from:" $wrongsnaps.data.name -foregroundcolor yellow
            [array]$sessiondata = $wrongsnaps.sessiondata
            write-host "Users being logged off are:" $sessiondata.username -foregroundcolor yellow
            if(!$preview){
                if($forcedlogoff){
                    write-host "Forcefully logging off users" -foregroundcolor yellow
                    $services1.session.Session_LogoffSessionsForced($sessiondata.id)
                }
                else{
                    write-host "Gracefully logging off users" -foregroundcolor yellow
                    $services1.session.Session_LogoffSessions($sessiondata.id)
                }
            }
        }
    }
    else{
        write-host "No machines found on a wrong snapshot" -foregroundcolor Green
    }
}
else{
    write-host "No machines found in $poolname" -foregroundcolor red
}

