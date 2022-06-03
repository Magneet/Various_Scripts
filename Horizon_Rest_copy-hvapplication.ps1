[CmdletBinding()]
param (
    [Parameter(Mandatory=$false,
    HelpMessage='Credential object as domain\username with password' )]
    [PSCredential] $Credentials,

    [Parameter(Mandatory=$true,  HelpMessage='FQDN of the connectionserver' )]
    [ValidateNotNullOrEmpty()]
    [string] $ConnectionServerFQDN,

    [parameter(Mandatory = $true,
    HelpMessage = "Name of the Application to copy")]
    [ValidateNotNullOrEmpty()]
    [string]$AppName,

    [Parameter(Mandatory=$true,  HelpMessage='FQDN of the connectionserver' )]
    [ValidateNotNullOrEmpty()]
    [string] $TargetConnectionServerfqdn,

    [parameter(Mandatory = $true,
    HelpMessage = "Type of pool to link the app to (VDI or RDS)")]
    [ValidateSet('VDI','RDS', IgnoreCase = $false)]
    [string]$TargetPoolType,

    [parameter(Mandatory = $true,
    HelpMessage = "Name of the Snapshot to use for the Golden Image.")]
    [ValidateNotNullOrEmpty()]
    [string]$TargetPoolName,

    [parameter(Mandatory = $true,
    HelpMessage = "Name of the RDS Farm.")]
    [ValidateNotNullOrEmpty()]
    [string]$TargetAppName
)

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
        [string] $ConnectionServerURL
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

function Get-HorizonRestData(){
    [CmdletBinding(DefaultParametersetName='None')] 
    param(
        [Parameter(Mandatory=$true,
        HelpMessage='url to the server i.e. https://pod1cbr1.loft.lab' )]
        [string] $ServerURL,

        [Parameter(Mandatory=$true,
        ParameterSetName="filteringandpagination",
        HelpMessage='Array of ordered hashtables' )]
        [array] $filters,

        [Parameter(Mandatory=$true,
        ParameterSetName="filteringandpagination",
        HelpMessage='Type of filter Options: And, Or' )]
        [ValidateSet('And','Or', IgnoreCase = $false)]
        [string] $Filtertype,

        [Parameter(Mandatory=$false,
        ParameterSetName="filteringandpagination",
        HelpMessage='Page size, default = 500' )]
        [int] $pagesize = 500,

        [Parameter(Mandatory=$true,
        HelpMessage='Part after the url in the swagger UI i.e. /external/v1/ad-users-or-groups' )]
        [string] $RestMethod,

        [Parameter(Mandatory=$true,
        HelpMessage='Part after the url in the swagger UI i.e. /external/v1/ad-users-or-groups' )]
        [PSCustomObject] $accessToken,

        [Parameter(Mandatory=$false,
        ParameterSetName="filteringandpagination",
        HelpMessage='$True for rest methods that contain pagination and filtering, default = False' )]
        [switch] $filteringandpagination,

        [Parameter(Mandatory=$false,
        ParameterSetName="id",
        HelpMessage='To be used with single id based queries like /monitor/v1/connection-servers/{id}' )]
        [string] $id
    )
    if($filteringandpagination){
        if ($filters){
            $filterhashtable = [ordered]@{}
            $filterhashtable.add('type',$filtertype)
            $filterhashtable.filters = @()
            foreach($filter in $filters){
                $filterhashtable.filters+=$filter
            }
            $filterflat=$filterhashtable | convertto-json -Compress
            $urlstart= $ServerURL+"/rest/"+$RestMethod+"?filter="+$filterflat+"&page="
        }
        else{
            $urlstart= $ServerURL+"/rest/"+$RestMethod+"?page="
        }
        $results = [System.Collections.ArrayList]@()
        $page = 1
        $uri = $urlstart+$page+"&size=$pagesize"
        $response = Invoke-RestMethod $uri -Method 'GET' -Headers (Get-HRHeader -accessToken $accessToken) -ResponseHeadersVariable responseheader
        $response.foreach({$results.add($_)}) | out-null
        if ($responseheader.HAS_MORE_RECORDS -contains "TRUE") {
            do {
                $page++
                $uri = $urlstart+$page+"&size=$pagesize"
                $response = Invoke-RestMethod $uri -Method 'GET' -Headers (Get-HRHeader -accessToken $accessToken) -ResponseHeadersVariable responseheader
                $response.foreach({$results.add($_)}) | out-null
            } until ($responseheader.HAS_MORE_RECORDS -notcontains "TRUE")
        }
    }
    elseif($id){
        $uri= $ServerURL+"/rest/"+$RestMethod+"/"+$id
        $results = Invoke-RestMethod $uri -Method 'GET' -Headers (Get-HRHeader -accessToken $accessToken) -ResponseHeadersVariable responseheader
    }
    else{
        $uri= $ServerURL+"/rest/"+$RestMethod
        $results = Invoke-RestMethod $uri -Method 'GET' -Headers (Get-HRHeader -accessToken $accessToken) -ResponseHeadersVariable responseheader
    }

    return $results
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


$ConnectionServerURL = "https://$ConnectionServerFQDN"

try{
    $accessToken = Open-HRConnection -username $username -password $UnsecurePassword -domain $Domain -ConnectionServerURL $ConnectionServerURL
}
catch{
    throw "Error Connecting: $_"
}
$filter=@()
$appfilter= [ordered]@{}
$appfilter.add('type','Equals')
$appfilter.add('name','name')
$appfilter.add('value',$AppName)
$filter+=$appfilter


$OriginalApp = Get-HorizonRestData -ServerURL $ConnectionServerURL -filteringandpagination -Filtertype "And" -filters $appfilter -RestMethod "inventory/v1/application-pools" -accessToken $accessToken
$originalicons=@()
# $OriginalApp
$originalapp_icons = $OriginalApp.icon_ids
# $originalapp_icons
foreach($icon_id in $originalapp_icons){
    # $icon_id
    $icon=Invoke-RestMethod -Method Get -uri "$ConnectionServerURL/rest/inventory/v1/application-icons/$icon_id" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)
    # $icon
    $originalicons += $icon
}
return $originalicons


# $vcenterid = ($vCenters | where-object {$_.name -like "*$vCenterURL*"}).id
# $datacenters = Invoke-RestMethod -Method Get -uri "$ConnectionServerURL/rest/external/v1/datacenters?vcenter_id=$vcenterid" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)
# $datacenterid = ($datacenters | where-object {$_.name -eq $DataCenterName}).id
# $basevms = Invoke-RestMethod -Method Get -uri "$ConnectionServerURL/rest/external/v1/base-vms?datacenter_id=$datacenterid&filter_incompatible_vms=false&vcenter_id=$vcenterid" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)
# $basevmid = ($basevms | where-object {$_.name -eq $baseVMName}).id
# $basesnapshots = Invoke-RestMethod -Method Get -uri "$ConnectionServerURL/rest/external/v1/base-snapshots?base_vm_id=$basevmid&vcenter_id=$vcenterid" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)
# $basesnapshotid = ($basesnapshots | where-object {$_.name -eq $BaseSnapShotName}).id
# $farms = Invoke-RestMethod -Method Get -uri "$ConnectionServerURL/rest/inventory/v2/farms" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)
# $farmid = ($farms | where-object {$_.name -eq $FarmName}).id
# $startdate = (get-date -UFormat %s)
# $datahashtable = [ordered]@{}
# $datahashtable.add('logoff_policy',$logoff_policy)
# $datahashtable.add('maintenance_mode',"IMMEDIATE")
# if($Scheduledtime){
#     $starttime = get-date $Scheduledtime
#     $epoch = ([DateTimeOffset]$starttime).ToUnixTimeMilliseconds()
#     $datahashtable.add('next_scheduled_time',$epoch)
# }
# $datahashtable.add('parent_vm_id',$basevmid)
# $datahashtable.add('snapshot_id',$basesnapshotid)
# $datahashtable.add('stop_on_first_error',$StoponError)
# $json = $datahashtable | convertto-json
# Invoke-RestMethod -Method Post -uri "$ConnectionServerURL/rest/inventory/v1/farms/$farmid/action/schedule-maintenance" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken) -body $json
