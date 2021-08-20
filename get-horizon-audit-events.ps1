[CmdletBinding(DefaultParameterSetName='noFilter')]
param (
    [Parameter(Mandatory=$false,
    HelpMessage='Credential object as domain\username with password' )]
    [PSCredential] $Credential,

    [Parameter(Mandatory=$true,  HelpMessage='FQDN of the connectionserver' )]
    [ValidateNotNullOrEmpty()]
    [string] $ConnectionServerFQDN,

    [Parameter(ParameterSetName='Filter',Mandatory=$true,HelpMessage = "Name of the data type to filter on.")]
    [Parameter(ParameterSetName='noFilter',Mandatory=$false,HelpMessage = "Name of the data type to filter on.")]
    [string]$filterdata,

    [Parameter(ParameterSetName='Filter',Mandatory=$true,HelpMessage = "Value to filter on.")]
    [Parameter(ParameterSetName='noFilter',Mandatory=$false,HelpMessage = "Value to filter on.")]
    [string]$filtervalue,

    [Parameter(ParameterSetName='Filter',HelpMessage = "FIltertype: Equals or Contains.")]
    [validateset("Equals","Contains")]
    [string]$filtertype

)

if($Credential){
    $creds = $credential
}
else{
    $creds = get-credential
}

$ErrorActionPreference = 'Stop'

# Loading powercli modules
Import-Module VMware.VimAutomation.HorizonView
Import-Module VMware.VimAutomation.Core

$hvserver1=connect-hvserver $ConnectionServerFQDN -credential $creds
$Services1= $hvServer1.ExtensionData

$queryservice=new-object vmware.hv.queryserviceservice
$defn = New-Object VMware.Hv.QueryDefinition
$defn.queryentitytype='AuditEventSummaryView'

if($filtertype){
    if($filtertype -eq "Contains"){
        $defn.Filter= New-Object VMware.Hv.QueryFilterContains -property @{'MemberName'=$filterdata; 'value'=$filtervalue}
    }
    else{
        $defn.Filter= New-Object VMware.Hv.QueryFilterEquals -property @{'MemberName'=$filterdata; 'value'=$filtervalue}
    }
}



$eventlist = @()
$GetNext = $false
$queryResults = $queryservice.QueryService_Create($Services1, $defn)
do {
    if ($GetNext) {
        $queryResults = $queryservice.QueryService_GetNext($Services1, $queryResults.id) 
    }
    $eventlist += $queryResults.results
    $GetNext = $true
}
while ($queryResults.remainingCount -gt 0)
$queryservice.QueryService_Delete($Services1, $queryResults.id)
return $eventlist
