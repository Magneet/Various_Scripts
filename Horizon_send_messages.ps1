<#
    .SYNOPSIS
    Send a message to all user sessions

    .DESCRIPTION
    This script uses the Horizon rest api's to all sessions in a horizon pod

    .EXAMPLE
    .\find_user_assigned_desktops.ps1 -Credential $creds -ConnectionServerFQDN pod2cbr1.loft.lab -message "test message" -message_type "ERROR"

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
    First version: 23-12-2021

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

function get-horizonsessions(){
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
        Get-HorizonRestData -ServerURL $url -RestMethod "/inventory/v1/sessions/" -accessToken $accessToken
    }
    catch{
        throw $_
    }
    return $results
}

function send-horizonmessage(){
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
        [string] $Message_Type
    )
    $jsonhashtable = [ordered]@{}
    $jsonhashtable.add('message',$message)
    $jsonhashtable.add('message_type',$Message_Type)
    $jsonhashtable.add('session_ids',$Session_Ids)

    $json = $jsonhashtable | convertto-json
    try{
        $results = Invoke-RestMethod -Method Post -uri "$ServerURL/rest/inventory/v1/sessions/action/send-message" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken) -body $json
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

$sessions = get-horizonsessions -accessToken $accessToken -ServerURL $url

send-horizonmessage -accessToken $accessToken -ServerURL $url -Message_Type $Message_Type -message $message -Session_Ids ($sessions).id