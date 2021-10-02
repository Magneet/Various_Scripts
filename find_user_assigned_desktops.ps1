<#
    .SYNOPSIS
    Retreives all machines a user is assigned to

    .DESCRIPTION
    This script uses the Horizon rest api's to query the Horizon database for all machines a user is assigned to.

    .EXAMPLE
    .\find_user_assigned_desktops.ps1 -Credential $creds -ConnectionServerFQDN pod2cbr1.loft.lab -UserName "User2"

    .PARAMETER Credential
    Mandatory: No
    Type: PSCredential
    Object with credentials for the connection server with domain\username and password

    .PARAMETER ConnectionServerFQDN
    Mandatory: Yes
    Default: String
    FQDN of the connection server to connect to

    .PARAMETER Username
    Mandatory: Yes
    Username of the user to look for

    .PARAMETER Domain
    Mandatory: Yes
    Domain to look in

    .NOTES
    Created by: Wouter Kursten
    First version: 02-10-2021

    .COMPONENT
    Powershell Core

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
    [string]$User = $false,

    [parameter(Mandatory = $true,
    HelpMessage = "DOmain where the user object exists.")]
    [string]$Domain = $false
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
        [string] $url
    )

    $Credentials = New-Object psobject -Property @{
        username = $username
        password = $password
        domain = $domain
    }

    return invoke-restmethod -Method Post -uri "$url/rest/login" -ContentType "application/json" -Body ($Credentials | ConvertTo-Json)
}

function Close-HRConnection(){
    param(
        $accessToken,
        $url
    )
    return Invoke-RestMethod -Method post -uri "$url/rest/logout" -ContentType "application/json" -Body ($accessToken | ConvertTo-Json)
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
        [ValidateSet('And','Or')]
        [string] $Filtertype,

        [Parameter(Mandatory=$false,
        ParameterSetName="filteringandpagination",
        HelpMessage='Page size, default = 500' )]
        [int] $pagesize = 500,

        [Parameter(Mandatory=$true,
        HelpMessage='Part after the url in the swagger UI i.e. /rest/external/v1/ad-users-or-groups' )]
        [string] $RestMethod,

        [Parameter(Mandatory=$true,
        HelpMessage='Part after the url in the swagger UI i.e. /rest/external/v1/ad-users-or-groups' )]
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

if($Credential){
    $creds = $credential
}
else{
    $creds = get-credential
}

$ErrorActionPreference = 'Stop'

$username=($creds.username).split("\")[1]
$domain=($creds.username).split("\")[0]
$password=$creds.password

$url = "https://$ConnectionServerFQDN"

$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password) 
$UnsecurePassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

$accessToken = Open-HRConnection -username $username -password $UnsecurePassword -domain $Domain -url $url

$userfilters = @()
$userfilter= [ordered]@{}
$userfilter.add('type','Equals')
$userfilter.add('name','name')
$userfilter.add('value',$User)
$userfilters+=$userfilter
$domainfilter= [ordered]@{}
$domainfilter.add('type','Equals')
$domainfilter.add('name','domain')
$domainfilter.add('value',$Domain)
$userfilters+=$domainfilter

$userobject = Get-HorizonRestData -ServerURL $url -filteringandpagination -Filtertype "And" -filters $userfilters -RestMethod "/external/v1/ad-users-or-groups" -accessToken $accessToken

$machinefilters = @()
$machinefilter= [ordered]@{}
$machinefilter.add('type','Contains')
$machinefilter.add('name','user_ids')
$machinefilter.add('value',($userobject).id)
$machinefilters+=$machinefilter
$machines = Get-HorizonRestData -ServerURL $url -filteringandpagination -Filtertype "And" -filters $machinefilters -RestMethod "/inventory/v1/machines" -accessToken $accessToken

return $machines

