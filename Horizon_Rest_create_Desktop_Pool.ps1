<#
    .SYNOPSIS
    Creates a new Golden Image to a Desktop Pool

    .DESCRIPTION
    This script uses the Horizon rest api's to create a new VMware Horizon Desktop Pool

    .EXAMPLE
    .\Horizon_Rest_create_Desktop_Pool.ps1 -Credentials $creds -ConnectionServerURL https://pod1cbr1.loft.lab -jsonfile 'D:\homelab\new-pool-rest.json' -vCenterURL pod1vcr1.loft.lab -DataCenterName "Datacenter_Loft" -ClusterName "Dell 620" -BaseVMName "W21h1-2021-11-05-13-00" -BaseSnapShotName "Created by Packer" -DatastoreNames  ("vdi-200","vdi-500") -VMFolderPath "/Datacenter_Loft/vm" -DesktopPoolName "Rest_Pool_demo2" -DesktopPoolDisplayName "Rest DIsplay name" -DesktopPoolDescription "rest description" -namingmethod "Rest-{n:fixed=2}"

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
    Name of the datacenter

    .PARAMETER BaseVMName
    Mandatory: Yes
    Name of the Golden Image VM

    .PARAMETER BaseSnapShotName
    Mandatory: Yes
    Name of the Golden Image Snapshot

    .PARAMETER DesktopPoolName
    Mandatory: Yes
    Name of the Desktop Pool to ctreate

    .PARAMETER jsonfile
    Mandatory: Yes
    Full path to the JSON file to use as base

    .PARAMETER ClusterName
    Mandatory: Yes
    Name of the vCenter Cluster to place the vm's in

    .PARAMETER DatastoreNames
    Mandatory: Yes
    Array of names of the datastores to use

    .PARAMETER VMFolderPath
    Mandatory: Yes
    Path to the folder where the folder with pool vm's will be placed including the datacenter with forward slashes so /datacenter/folder

    .PARAMETER DesktopPoolDisplayName
    Mandatory: Yes
    Display name of the desktop pool

    .PARAMETER DesktopPoolDescription
    Mandatory: Yes
    Description of the desktop pool

    .PARAMETER NamingMethod
    Mandatory: Yes
    Naming method of the vm's

    .NOTES
    Minimum required version: VMware Horizon 8 2111
    Created by: Wouter Kursten
    First version: 08-12-2021

    .COMPONENT
    Powershell Core
#>

<#
Copyright © 2021 Wouter Kursten
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, 
including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
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

    [parameter(Mandatory = $true,
    HelpMessage = "Display Name of the Desktop Pool.")]
    [ValidateNotNullOrEmpty()]
    [string]$DesktopPoolDisplayName,

    [parameter(Mandatory = $true,
    HelpMessage = "Description of the Desktop Pool.")]
    [ValidateNotNullOrEmpty()]
    [string]$DesktopPoolDescription,

    [parameter(Mandatory = $true,
    HelpMessage = "Name of the cluster where the Desktop Pool will be placed.")]
    [ValidateNotNullOrEmpty()]
    [string]$ClusterName,

    [parameter(Mandatory = $true,
    HelpMessage = "Array of names for the datastores where the Desktop will be placed.")]
    [ValidateNotNullOrEmpty()]
    [array]$DatastoreNames,

    [parameter(Mandatory = $true,
    HelpMessage = "Path to the folder where the folder for the Desktop Pool will be placed i.e. /Datacenter_Loft/vm")]
    [ValidateNotNullOrEmpty()]
    [string]$VMFolderPath,

    [parameter(Mandatory = $true,
    HelpMessage = "Naming method for the VDI machines.")]
    [ValidateNotNullOrEmpty()]
    [string]$NamingMethod,

    [parameter(Mandatory = $true,
    HelpMessage = "Full path to the Json with Desktop Pool details.")]
    [ValidateNotNullOrEmpty()]
    [string]$jsonfile
)

try{
    test-path $jsonfile  | out-null
}
catch{
    throw "Json file not found"
}
try{
    $sourcejson = get-content $jsonfile | ConvertFrom-Json
}
catch{
    throw "Error importing json file"
}

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
$clusters = Invoke-RestMethod -Method Get -uri "$ConnectionServerURL/rest/external/v1/hosts-or-clusters?datacenter_id=$datacenterid&vcenter_id=$vcenterid" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)
$clusterid = ($clusters | where-object {$_.details.name -eq $ClusterName}).id
$datastores = Invoke-RestMethod -Method Get -uri "$ConnectionServerURL/rest/external/v1/datastores?host_or_cluster_id=$clusterid&vcenter_id=$vcenterid" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)
$datastoreobjects = @()
foreach ($datastoreName in $DatastoreNames){
    $datastoreid = ($datastores | where-object {$_.name -eq $datastoreName}).id
    [PSCustomObject]$dsobject=[ordered]@{
        datastore_id = $datastoreid
    }
    $datastoreobjects+=$dsobject

}
$resourcepools = Invoke-RestMethod -Method Get -uri "$ConnectionServerURL/rest/external/v1/resource-pools?host_or_cluster_id=$clusterid&vcenter_id=$vcenterid" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)
$resourcepoolid = $resourcepools[0].id
$vmfolders = Invoke-RestMethod -Method Get -uri "$ConnectionServerURL/rest/external/v1/vm-folders?datacenter_id=$datacenterid&vcenter_id=$vcenterid" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)
$vmfolderid = ($vmfolders | where-object {$_.path -eq $VMFolderPath}).id
$basevms = Invoke-RestMethod -Method Get -uri "$ConnectionServerURL/rest/external/v1/base-vms?datacenter_id=$datacenterid&filter_incompatible_vms=false&vcenter_id=$vcenterid" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)
$basevmid = ($basevms | where-object {$_.name -eq $baseVMName}).id
$basesnapshots = Invoke-RestMethod -Method Get -uri "$ConnectionServerURL/rest/external/v1/base-snapshots?base_vm_id=$basevmid&vcenter_id=$vcenterid" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)
$basesnapshotid = ($basesnapshots | where-object {$_.name -eq $BaseSnapShotName}).id
$sourcejson.provisioning_settings.base_snapshot_id = $basesnapshotid
$sourcejson.provisioning_settings.datacenter_id = $datacenterid
$sourcejson.provisioning_settings.host_or_cluster_id = $clusterid
$sourcejson.provisioning_settings.parent_vm_id = $basevmid
$sourcejson.provisioning_settings.vm_folder_id = $vmfolderid
$sourcejson.provisioning_settings.resource_pool_id = $resourcepoolid
$sourcejson.vcenter_id = $vcenterid
$sourcejson.storage_settings.datastores = $datastoreobjects
$sourcejson.name = $DesktopPoolName
$sourcejson.display_name = $DesktopPoolDisplayName
$sourcejson.description = $DesktopPoolDescription
$sourcejson.pattern_naming_settings.naming_pattern = $namingmethod

$json = $sourcejson | convertto-json -Depth 100
try{
    Invoke-RestMethod -Method Post -uri "$ConnectionServerURL/rest/inventory/v1/desktop-pools" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken) -body $json
}
catch{
    throw $_
}