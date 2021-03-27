[CmdletBinding()]
Param
(
    [Parameter(Mandatory=$False,
    ParameterSetName="separatecredentials",
    HelpMessage='Enter a username' )]
    [ValidateNotNullOrEmpty()]
    [string] $Username,

    [Parameter(Mandatory=$false,
    ParameterSetName="separatecredentials",
    HelpMessage='Domain i.e. loft.lab' )]
    [string] $Domain,

    [Parameter(Mandatory=$false,
    ParameterSetName="separatecredentials",
    HelpMessage='Password in plain text' )]
    [string] $Password,

    [Parameter(Mandatory=$true,  HelpMessage='FQDN of the connectionserver' )]
    [ValidateNotNullOrEmpty()]
    [string] $ConnectionServerFQDN,

    [Parameter(Mandatory=$false,
    ParameterSetName="credsfile",
    HelpMessage='Path to credentials xml file' )]
    [ValidateNotNullOrEmpty()]
    [string] $Credentialfile,

    [Parameter(Mandatory=$false,  HelpMessage='username of the user to logoff (domain\user i.e. loft.lab\user1')]
    [ValidateNotNullOrEmpty()]
    [string[]] $TargetUsers,

    [Parameter(Mandatory=$false, HelpMessage='Name of the desktop pool the machine belongs to')]
	[string] $TargetPool,

    [Parameter(Mandatory=$false, HelpMessage='dns name of the machine the user is on i.d. lp-002.loft.lab')]
	[string] $TargetMachine,

    [Parameter(Mandatory=$false, HelpMessage='domain for the target users')]
	[string] $TargetDomain
)

if($Credentialfile -and ((test-path $Credentialfile) -eq $true)){
    try{
        write-host "Using credentialsfile"
        $credentials=Import-Clixml $Credentialfile
        $username=($credentials.username).split("\")[1]
        $domain=($credentials.username).split("\")[0]
        $secpw=$credentials.password
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secpw)
        $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    }
    catch{
        write-error -Message "Error importing credentials"
        break
    }
}
elseif($Credentials -and ((test-path $credentials) -eq $false)){
    write-error "Invalid Path to credentials file"
    break
}
elseif($username -and $Domain -and $Password){
    write-host "Using separate credentials"
}


function Get-HVDesktopPool {
    param (
        [parameter(Mandatory = $true,
        HelpMessage = "Displayname of the Desktop Pool.")]
        [string]$HVPoolName,
        [parameter(Mandatory = $true,
        HelpMessage = "The Horizon View Connection server object.")]
        [VMware.VimAutomation.HorizonView.Impl.V1.ViewObjectImpl]$HVConnectionServer
    )
    # Try to get the Desktop pools in this pod
    try {
        # create the service object first
        [VMware.Hv.QueryServiceService]$queryService = New-Object VMware.Hv.QueryServiceService
        # Create the object with the definiton of what to query
        [VMware.Hv.QueryDefinition]$defn = New-Object VMware.Hv.QueryDefinition
        # entity type to query
        $defn.queryEntityType = 'DesktopSummaryView'
        # Filter on the correct displayname
        $defn.Filter = New-Object VMware.Hv.QueryFilterEquals -property @{'memberName'='desktopSummaryData.displayName'; 'value' = "$HVPoolname"}
        # Perform the actual query
        [array]$queryResults= ($queryService.queryService_create($HVConnectionServer.extensionData, $defn)).results
        # Remove the query
        $queryService.QueryService_DeleteAll($HVConnectionServer.extensionData)
        # Return the results
        if (!$queryResults){
            write-host "Can't find $HVPoolName, exiting."
            exit
        }
        else {
            return $queryResults
        }
    }
    catch {
        write-host 'There was a problem retreiving the Horizon View Desktop Pool.'
    }
}

function Get-HVDesktopMachine {
    param (
        [parameter(Mandatory = $true,
        HelpMessage = "ID of the Desktop Pool.")]
        [VMware.Hv.DesktopId]$HVPoolID,
        [parameter(Mandatory = $true,
        HelpMessage = "Name of the Desktop machine.")]
        [string]$HVMachineName,
        [parameter(Mandatory = $true,
        HelpMessage = "The Horizon View Connection server object.")]
        [VMware.VimAutomation.HorizonView.Impl.V1.ViewObjectImpl]$HVConnectionServer
    )

    try {
        # create the service object first
        [VMware.Hv.QueryServiceService]$queryService = New-Object VMware.Hv.QueryServiceService
        # Create the object with the definiton of what to query
        [VMware.Hv.QueryDefinition]$defn = New-Object VMware.Hv.QueryDefinition
        # entity type to query
        $defn.queryEntityType = 'MachineDetailsView'
        # Filter so we get the correct machine in the correct pool
        $poolfilter = New-Object VMware.Hv.QueryFilterEquals -property @{'memberName'='desktopData.id'; 'value' = $HVPoolID}
        $machinefilter = New-Object VMware.Hv.QueryFilterEquals -property @{'memberName'='data.name'; 'value' = "$HVMachineName"}
        $filterlist = @()
        $filterlist += $poolfilter
        $filterlist += $machinefilter
        $filterAnd = New-Object VMware.Hv.QueryFilterAnd
        $filterAnd.Filters = $filterlist
        $defn.Filter = $filterAnd
        # Perform the actual query
        [array]$queryResults= ($queryService.queryService_create($HVConnectionServer.extensionData, $defn)).results
        # Remove the query
        $queryService.QueryService_DeleteAll($HVConnectionServer.extensionData)
        # Return the results
        if (!$queryResults){
            write-host "Can't find $HVPoolName, exiting."
            exit
        }
        else{
            return $queryResults
        }
    }
    catch {
        write-host 'There was a problem retreiving the Horizon View Desktop Pool.'
    }
}

function Get-HVUser {
    param (
        [parameter(Mandatory = $true,
        HelpMessage = "User loginname..")]
        [string]$HVUserLoginName,
        [parameter(Mandatory = $true,
        HelpMessage = "Name of the Domain.")]
        [string]$HVDomain,
        [parameter(Mandatory = $true,
        HelpMessage = "The Horizon View Connection server object.")]
        [VMware.VimAutomation.HorizonView.Impl.V1.ViewObjectImpl]$HVConnectionServer
    )

    try {
        # create the service object first
        [VMware.Hv.QueryServiceService]$queryService = New-Object VMware.Hv.QueryServiceService
        # Create the object with the definiton of what to query
        [VMware.Hv.QueryDefinition]$defn = New-Object VMware.Hv.QueryDefinition
        # entity type to query
        $defn.queryEntityType = 'ADUserOrGroupSummaryView'
        # Filter to get the correct user
        $userloginnamefilter = New-Object VMware.Hv.QueryFilterEquals -property @{'memberName'='base.loginName'; 'value' = $HVUserLoginName}
        $domainfilter = New-Object VMware.Hv.QueryFilterEquals -property @{'memberName'='base.domain'; 'value' = "$HVDomain"}
        $filterlist = @()
        $filterlist += $userloginnamefilter
        $filterlist += $domainfilter
        $filterAnd = New-Object VMware.Hv.QueryFilterAnd
        $filterAnd.Filters = $filterlist
        $defn.Filter = $filterAnd
        # Perform the actual query
        [array]$queryResults= ($queryService.queryService_create($HVConnectionServer.extensionData, $defn)).results
        # Remove the query
        $queryService.QueryService_DeleteAll($HVConnectionServer.extensionData)
        # Return the results
        if (!$queryResults){
            write-host "Can't find user $HVUserLoginName in domain $HVDomain, exiting."
            exit
        }
        else {
            return $queryResults
        }
    }
    catch {
        write-host 'There was a problem retreiving the user.'
    }
}



$hvserver1=connect-hvserver $ConnectionServerFQDN -user $username -domain $domain -password $password
$Services1= $hvServer1.ExtensionData

$desktop_pool=Get-HVDesktopPool -hvpoolname $TargetPool -HVConnectionServer $hvserver1

$poolid=$desktop_pool.id

$machine = get-hvdesktopmachine -HVConnectionServer $hvserver1 -HVMachineName $TargetMachine -HVPoolID $poolid
$machineid = $machine.id
$useridlist=@()

foreach ($targetuser in $TargetUsers){
    $user = Get-HVUser -HVConnectionServer $hvserver1 -hvdomain $TargetDomain -HVUserLoginName $targetUser
    $useridlist+=$user.id
}

$Services1.Machine.Machine_assignUsers($machineid, $useridlist)

