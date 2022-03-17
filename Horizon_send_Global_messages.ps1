<#
    .SYNOPSIS
    Send a message to all global sessions

    .DESCRIPTION
    This script uses the Horizon rest api's to all global sessions in a horizon cloud pod 

    .EXAMPLE
    .\Horizon_send_Global_messages.ps1 -Credential $creds -ConnectionServerFQDN pod2cbr1.loft.lab -message "test message" -message_type "ERROR"

    .PARAMETER Credential
    Mandatory: No
    Type: PSCredential
    Object with credentials for the connection server with domain\username and password

    .PARAMETER ConnectionServerFQDN
    Mandatory: Yes
    Default: String
    FQDN of the connection server to connect to

    .PARAMETER message
    Mandatory: Yes
    Message to send to the users

    .PARAMETER message_type
    Mandatory: Yes
    Message type: INFO, ERROR or WARNING

    .NOTES
    Created by: Wouter Kursten
    First version: 17-03-2022

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

    [Parameter(Mandatory=$true,
    HelpMessage='url to the server i.e. https://pod1cbr1.loft.lab' )]
    [string] $Message,

    [Parameter(Mandatory=$true,
    HelpMessage='url to the server i.e. https://pod1cbr1.loft.lab' )]
    [validateset("ERROR","WARNING","INFO", IgnoreCase = $false)]
    [string] $Message_Type
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
        write-host $uri
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

function send-horizonglobalmessage(){
    [CmdletBinding(DefaultParametersetName='None')] 
    param(
        [Parameter(Mandatory=$true,
        HelpMessage='url to the server i.e. https://pod1cbr1.loft.lab' )]
        [string] $ServerURL,

        [Parameter(Mandatory=$true,
        HelpMessage='Part after the url in the swagger UI i.e. /external/v1/ad-users-or-groups' )]
        [PSCustomObject] $accessToken,

        [Parameter(Mandatory=$true,
        HelpMessage='url to the server i.e. https://pod1cbr1.loft.lab' )]
        [array] $Session_Ids,

        [Parameter(Mandatory=$true,
        HelpMessage='url to the server i.e. https://pod1cbr1.loft.lab' )]
        [string] $Message,

        [Parameter(Mandatory=$true,
        HelpMessage='url to the server i.e. https://pod1cbr1.loft.lab' )]
        [validateset("ERROR","WARNING","INFO", IgnoreCase = $false)]
        [string] $Message_Type,

        [Parameter(Mandatory=$true,
        HelpMessage='Id of the Local pod to query' )]
        [string] $podid
    )

    $jsonhashtable = [ordered]@{}
    $jsonhashtable.global_session_action_specs=@()
    $sessiondetailshashtable = [ordered]@{}
    $sessiondetailshashtable.ids=$Session_Ids
    $sessiondetailshashtable.pod_id=$podid
    $jsonhashtable.global_session_action_specs+=$sessiondetailshashtable
    $jsonhashtable.message = $message
    $jsonhashtable.message_type = $Message_Type
    $json = $jsonhashtable | convertto-json -depth 100

    try{
        $results = Invoke-RestMethod -Method Post -uri "$ServerURL/rest/inventory/v1/global-sessions/action/send-message" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken) -body $json
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

$pods=get-pods -accessToken $accessToken -ServerURL $url

foreach($pod in $pods){
    $podid=$pod.id
    $sessions = get-horizonglobalsessions -accessToken $accessToken -ServerURL $url -podid $podid
    send-horizonglobalmessage -accessToken $accessToken -ServerURL $url -Message_Type $Message_Type -message $message -Session_Ids ($sessions).id -podid $podid
}