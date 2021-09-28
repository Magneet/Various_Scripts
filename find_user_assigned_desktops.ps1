<#
    .SYNOPSIS
    Retreives all machines a user is assigned to

    .DESCRIPTION
    This script uses the Horizon soap api's to query the Horizon database for all machines a user is assigned to.

    .EXAMPLE
    .\find_user_assigned_desktops.ps1 -Credential $creds -ConnectionServerFQDN pod2cbr1.loft.lab -UserName "User2"

    .PARAMETER Credential
    Mandatory: Yes
    Type: PSCredential
    Object with credentials for the connection server with domain\username and password

    .PARAMETER ConnectionServerFQDN
    Mandatory: No
    Default: String
    FQDN of the connection server to connect to

    .PARAMETER Username
    Mandatory: No
    Username of the user to look for

    .PARAMETER Domain
    Mandatory: No
    Domain to look in

    .NOTES
    Created by: Wouter Kursten
    First version: 28-09-2021

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
    HelpMessage = "Username of the user to look for.")]
    [string]$UserName = $false,

    [parameter(Mandatory = $true,
    HelpMessage = "DOmain where the user object exists.")]
    [string]$Domain = $false
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

$hvserver=connect-hvserver $ConnectionServerFQDN -credential $creds

# --- Get Services for interacting with the Horizon API Service ---
$Services= $hvServer.ExtensionData

# Search for UserID
$queryservice=new-object vmware.hv.queryserviceservice
$defn = New-Object VMware.Hv.QueryDefinition
$defn.queryentitytype='ADUserOrGroupSummaryView'

# Filter for the correct user & domain
$filter1 = New-Object VMware.Hv.QueryFilterEquals
$filter1.membername='base.domain'
$filter1.value=$Domain
$filter2 = New-Object VMware.Hv.QueryFilterEquals
$filter2.membername='base.name'
$filter2.value=$UserName
$filter=new-object vmware.hv.QueryFilterAnd
$filter.filters=@($filter1, $filter2)
$defn.filter=$filter

# Perform the query
$UserObject = ($queryService.QueryService_Create($Services, $defn)).results
$Services.QueryService.QueryService_DeleteAll()


# Search for machine details
$queryservice=new-object vmware.hv.queryserviceservice
$defn = New-Object VMware.Hv.QueryDefinition
$defn.queryentitytype='MachineDetailsView'

# We need an array for the filter


$defn.filter = New-Object VMware.Hv.QueryFilterEquals -Property @{ 'memberName' = 'data.assignedUser'; 'value' = $userobject.id}
$MachinesObject  = ($queryService.QueryService_Create($Services, $defn)).results
$Services.QueryService.QueryService_DeleteAll()
return $MachinesObject


