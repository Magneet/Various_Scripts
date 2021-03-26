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

    [Parameter(Mandatory=$false, HelpMessage='Synchronise the local site only' )]
    [switch] $Force,

    [Parameter(Mandatory=$false,  HelpMessage='username of the user to logoff (domain\user i.e. loft.lab\user1')]
    [ValidateNotNullOrEmpty()]
    [string] $TargetUser,

    [Parameter(Mandatory=$false, HelpMessage='dns name of the machine the user is on i.d. lp-002.loft.lab')]
	[string] $TargetMachine
) 

if($Credentialfile -and ((test-path $Credentialfile) -eq $true)){
    try{
        write-host "Using credentialsfile"
        $credentials=Import-Clixml $Credentialfile
        $username=($credentials.username).split("\")[1]
        $domain=($credentials.username).split("\")[0]
        $password=$credentials.password
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
        $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    }
    catch{
        write-error -Message "Error importing credentials"
        break
    }
}
elseif($Credentials -and ((test-path $credentials) -eq $false)){
    write-error "Invalid Path to credentials file"
}
elseif($username -and $Domain -and $Password){
    write-host "Using separate credentials"
}


$hvserver1=connect-hvserver $ConnectionServerFQDN -user $username -domain $domain -password $password
$Services1= $hvServer1.ExtensionData

$queryService = New-Object VMware.Hv.QueryServiceService
$sessionfilterspec = New-Object VMware.Hv.QueryDefinition
$sessionfilterspec.queryEntityType = 'SessionLocalSummaryView'
$sessionfilter1= New-Object VMware.Hv.QueryFilterEquals
$sessionfilter1.membername='namesData.userName'
$sessionfilter1.value=$TargetUser
$sessionfilter2= New-Object VMware.Hv.QueryFilterEquals
$sessionfilter2.membername='namesData.machineOrRDSServerDNS'
$sessionfilter2.value=$TargetMachine
$sessionfilter=new-object vmware.hv.QueryFilterAnd
$sessionfilter.filters=@($sessionfilter1, $sessionfilter2)
$sessionfilterspec.filter=$sessionfilter
$session=($queryService.QueryService_Create($Services1, $sessionfilterspec)).results
$queryService.QueryService_DeleteAll($services1)
if($session.count -eq 0){
    write-host "No session found for $targetuser on $targetmachine"
    break
}

if($Force){
    write-host "Forcefully logging off $targetUser from $targetmachine"
    $Services1.Session.Session_Logoffforced($session.id)
}
else{
    write-host "Logging off $targetUser from $targetmachine"
    try{
        $Services1.Session.Session_Logoff($session.id)
    }
    catch{
        write-error "error logging the user off, maybe the sessions was locked. Try with -force"
    }
}

