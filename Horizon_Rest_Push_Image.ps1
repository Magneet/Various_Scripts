<#
    .SYNOPSIS
    Pushes a new Golden Image to a Desktop Pool

    .DESCRIPTION
    This script uses the Horizon rest api's to push a new golden image to a VMware Horizon Desktop Pool

    .EXAMPLE
    .\Horizon_Rest_Push_Image.ps1 -ConnectionServerURL https://pod1cbr1.loft.lab -Credentials $creds -vCenterURL "https://pod1vcr1.loft.lab" -DataCenterName "Datacenter_Loft" -baseVMName "W21h1-2021-09-08-15-48" -BaseSnapShotName "Demo Snapshot" -DesktopPoolName "Pod01-Pool02"

    .PARAMETER Credential
    Mandatory: No
    Type: PSCredential
    Object with credentials for the connection server with domain\username and password. If not supplied the script will ask for user and password.

    .PARAMETER ConnectionServerURL
    Mandatory: Yes
    Default: String
    URL of the connection server to connect to

    .PARAMETER vCenterURL
    Mandatory: Yes
    Username of the user to look for

    .PARAMETER DataCenterName
    Mandatory: Yes
    Domain to look in

    .PARAMETER BaseVMName
    Mandatory: Yes
    Domain to look in

    .PARAMETER BaseSnapShotName
    Mandatory: Yes
    Domain to look in

    .PARAMETER DesktopPoolName
    Mandatory: Yes
    Domain to look in

    .PARAMETER StoponError
    Mandatory: No
    Boolean to stop on error or not

    .PARAMETER logoff_policy
    Mandatory: No
    String FORCE_LOGOFF or WAIT_FOR_LOGOFF to set the logoff policy.

    .PARAMETER Scheduledtime
    Mandatory: No
    Time to schedule the image push in [DateTime] format.

    .NOTES
    Minimum required version: VMware Horizon 8 2012
    Created by: Wouter Kursten
    First version: 03-11-2021

    .COMPONENT
    Powershell Core
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$false,
    HelpMessage='Credential object as domain\username with password' )]
    [PSCredential] $Credentials,

    [Parameter(Mandatory=$true,  HelpMessage='FQDN of the connectionserver' )]
    [ValidateNotNullOrEmpty()]
    [string] $ConnectionServerURL,

    [parameter(Mandatory = $true,
    HelpMessage = "URL of the vCenter to look in i.e. https://vcenter.domain.lab")]
    [ValidateNotNullOrEmpty()]
    [string]$vCenterURL,

    [parameter(Mandatory = $true,
    HelpMessage = "Name of the Datacenter to look in.")]
    [ValidateNotNullOrEmpty()]
    [string]$DataCenterName,

    [parameter(Mandatory = $true,
    HelpMessage = "Name of the Golden Image VM.")]
    [ValidateNotNullOrEmpty()]
    [string]$BaseVMName,

    [parameter(Mandatory = $true,
    HelpMessage = "Name of the Snapshot to use for the Golden Image.")]
    [ValidateNotNullOrEmpty()]
    [string]$BaseSnapShotName,

    [parameter(Mandatory = $true,
    HelpMessage = "Name of the Desktop Pool.")]
    [ValidateNotNullOrEmpty()]
    [string]$DesktopPoolName,

    [parameter(Mandatory = $false,
    HelpMessage = "Name of the Desktop Pool.")]
    [ValidateNotNullOrEmpty()]
    [bool]$StoponError = $true,

    [parameter(Mandatory = $false,
    HelpMessage = "Name of the Desktop Pool.")]
    [ValidateSet('WAIT_FOR_LOGOFF','FORCE_LOGOFF', IgnoreCase = $false)]
    [string]$logoff_policy = "WAIT_FOR_LOGOFF",

    [parameter(Mandatory = $false,
    HelpMessage = "DateTime object for the moment of scheduling the image push.Defaults to immediately")]
    [datetime]$Scheduledtime
)
if($Credentials){
    $username=($credentials.username).split("\")[1]
    $domain=($credentials.username).split("\")[0]
    $password=$credentials.password
}
else{
    $credentials = Get-Credential
    $username=($credentials.username).split("\")[1]
    $domain=($credentials.username).split("\")[0]
    $password=$credentials.password
}

$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password) 
$UnsecurePassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

function Get-HRHeader(){
    param($accessToken)
    return @{
        'Authorization' = 'Bearer ' + $($accessToken.access_token)
        'Content-Type' = "application/json"
    }
}
function Open-HRConnection(){
    param(
        [string] $username,
        [string] $password,
        [string] $domain,
        [string] $url
    )

    $Credentials = New-Object psobject -Property @{
        username = $username
        password = $password
        domain = $domain
    }

    return invoke-restmethod -Method Post -uri "$ConnectionServerURL/rest/login" -ContentType "application/json" -Body ($Credentials | ConvertTo-Json)
}
function Close-HRConnection(){
    param(
        $accessToken,
        $ConnectionServerURL
    )
    return Invoke-RestMethod -Method post -uri "$ConnectionServerURL/rest/logout" -ContentType "application/json" -Body ($accessToken | ConvertTo-Json)
}

try{
    $accessToken = Open-HRConnection -username $username -password $UnsecurePassword -domain $Domain -url $ConnectionServerURL
}
catch{
    throw "Error Connecting: $_"
}

$vCenters = Invoke-RestMethod -Method Get -uri "$ConnectionServerURL/rest/monitor/v2/virtual-centers" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)
$vcenterid = ($vCenters | where-object {$_.name -like "*$vCenterURL*"}).id
$datacenters = Invoke-RestMethod -Method Get -uri "$ConnectionServerURL/rest/external/v1/datacenters?vcenter_id=$vcenterid" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)
$datacenterid = ($datacenters | where-object {$_.name -eq $DataCenterName}).id
$basevms = Invoke-RestMethod -Method Get -uri "$ConnectionServerURL/rest/external/v1/base-vms?datacenter_id=$datacenterid&filter_incompatible_vms=false&vcenter_id=$vcenterid" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)
$basevmid = ($basevms | where-object {$_.name -eq $baseVMName}).id
$basesnapshots = Invoke-RestMethod -Method Get -uri "$ConnectionServerURL/rest/external/v1/base-snapshots?base_vm_id=$basevmid&vcenter_id=$vcenterid" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)
$basesnapshotid = ($basesnapshots | where-object {$_.name -eq $BaseSnapShotName}).id
$desktoppools = Invoke-RestMethod -Method Get -uri "$ConnectionServerURL/rest/inventory/v1/desktop-pools" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)
$desktoppoolid = ($desktoppools | where-object {$_.name -eq $DesktopPoolName}).id
$startdate = (get-date -UFormat %s)
$datahashtable = [ordered]@{}
$datahashtable.add('logoff_policy',$logoff_policy)
$datahashtable.add('parent_vm_id',$basevmid)
$datahashtable.add('snapshot_id',$basesnapshotid)
if($Scheduledtime){
    $starttime = get-date $Scheduledtime
    $epoch = ([DateTimeOffset]$starttime).ToUnixTimeMilliseconds()
    $datahashtable.add('start_time',$epoch)
}

$datahashtable.add('stop_on_first_error',$StoponError)
$json = $datahashtable | convertto-json
Invoke-RestMethod -Method Post -uri "$ConnectionServerURL/rest/inventory/v1/desktop-pools/$desktoppoolid/action/schedule-push-image" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken) -body $json
