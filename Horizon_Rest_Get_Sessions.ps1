<#
    .SYNOPSIS
    Gets all (global) sessions for an Horizon environment

    .DESCRIPTION
    This script uses the Horizon rest api's to all gather alls essions in a Horizon (Cloud Pod) environment

    .EXAMPLE
    .\Horizon_Rest_Get_Sessions.ps1 -Credential $creds -ConnectionServerFQDN pod2cbr1.loft.lab

    .EXAMPLE
    .\Horizon_Rest_Get_Sessions.ps1 -Credential $creds -ConnectionServerFQDN pod2cbr1.loft.lab -global

    .EXAMPLE
    .\Horizon_Rest_Get_Sessions.ps1 -Credential $creds -ConnectionServerFQDN pod2cbr1.loft.lab -pod_name "Horizon_pod2"

    .PARAMETER Credential
    Mandatory: No
    Type: PSCredential
    Object with credentials for the connection server with domain\username and password

    .PARAMETER ConnectionServerFQDN
    Mandatory: Yes
    Default: String
    FQDN of the connection server to connect to

    .PARAMETER global
    Mandatory: No
    Switch to select global sessions or only sessions for the local pod (Horizon 2111 and later)

    .PARAMETER pod_name
    Mandatory: No
    String for name of the pod to get sessions for. (Horizon 2111 and later)

    .NOTES
    Created by: Wouter Kursten
    First version: 03-06-2022

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

    [Parameter(Mandatory=$false,
    ParameterSetName="globalsessions",
    HelpMessage='Parameter to select Global Sessions' )]
    [switch] $global,

    [Parameter(Mandatory=$false,
    ParameterSetName="globalsessions",
    HelpMessage='Name of the pod to get the sessions for, needs -Global, defaults to *' )]
    [string] $pod_name
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

        [Parameter(Mandatory=$false,
        ParameterSetName="filteringandpagination",
        HelpMessage='Array of ordered hashtables' )]
        [array] $filters,

        [Parameter(Mandatory=$false,
        ParameterSetName="filteringandpagination",
        HelpMessage='Type of filter Options: And, Or' )]
        [ValidateSet('And','Or')]
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
        [string] $id,

        [Parameter(Mandatory=$false,
        HelpMessage='Extra additions to the query url that comes before the paging/filtering parts like brokering_pod_id=806ca in /rest/inventory/v1/global-sessions?brokering_pod_id=806ca&page=2&size=100' )]
        [string] $urldetails
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
            if($urldetails){
                $urlstart= $ServerURL+"/rest/"+$RestMethod+"?"+$urldetails+"&filter="+$filterflat+"&page="
            }
            else{
                $urlstart= $ServerURL+"/rest/"+$RestMethod+"?filter="+$filterflat+"&page="
            }
        }
        else{
            if($urldetails){
                $urlstart= $ServerURL+"/rest/"+$RestMethod+"?"+$urldetails+"&page="
            }
            else{
                $urlstart= $ServerURL+"/rest/"+$RestMethod+"?page="
            }
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
        if($urldetails){
            $uri= $ServerURL+"/rest/"+$RestMethod+"?"+$urldetails
        }
        else{
            $uri= $ServerURL+"/rest/"+$RestMethod
        }

        $results = Invoke-RestMethod $uri -Method 'GET' -Headers (Get-HRHeader -accessToken $accessToken) -ResponseHeadersVariable responseheader
    }

    return $results
}

function get-horizonglobalsessions(){
    [CmdletBinding(DefaultParametersetName='None')] 
    param(
        [Parameter(Mandatory=$true,
        HelpMessage='url to the server i.e. https://pod1cbr1.loft.lab' )]
        [string] $ServerURL,

        [Parameter(Mandatory=$true,
        HelpMessage='Part after the url in the swagger UI i.e. /external/v1/ad-users-or-groups' )]
        [PSCustomObject] $accessToken,

        [Parameter(Mandatory=$true,
        HelpMessage='Id of the Local pod to query' )]
        [string] $podid
    )
    try{
        $results=Get-HorizonRestData -ServerURL $url -RestMethod "/inventory/v1/global-sessions" -accessToken $accessToken -urldetails "pod_id=$podid"
    }
    catch{
        throw $_
    }
    return $results
}

function Get-Pods(){
    [CmdletBinding(DefaultParametersetName='None')] 
    param(
        [Parameter(Mandatory=$true,
        HelpMessage='url to the server i.e. https://pod1cbr1.loft.lab' )]
        [string] $ServerURL,

        [Parameter(Mandatory=$true,
        HelpMessage='Part after the url in the swagger UI i.e. /external/v1/ad-users-or-groups' )]
        [PSCustomObject] $accessToken
    )

    try{
        $results=Get-HorizonRestData -ServerURL $url -RestMethod "/federation/v1/pods" -accessToken $accessToken
    }
    catch{
        throw $_
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


if($global){
    $pods=get-pods -accessToken $accessToken -ServerURL $url
    if($pod_name){
        $pod = $pods | Where-Object {$_.name -eq $pod_name}
        $podid=$pod.id
        $sessions = get-horizonglobalsessions -accessToken $accessToken -ServerURL $url -podid $podid -filteringandpagination
        return $sessions
    }
    else{
        $sessions=@()
        foreach ($pod in $pods){
            $podid=$pod.id
            $sessions += get-horizonglobalsessions -accessToken $accessToken -ServerURL $url -podid $podid -filteringandpagination
        }
        return $sessions
    }
}
else{
    $sessions = $sessions += get-horizonglobalsessions -accessToken $accessToken -ServerURL $url -filteringandpagination
    return $sessions
}