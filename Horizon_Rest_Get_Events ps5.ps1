<#
    .SYNOPSIS
    Exports Horizon Event Database entries

    .DESCRIPTION
    This script uses the Horizon REST API's to extract Horizon Event Database Entries

    .PARAMETER Credential
    Mandatory: No (unless MemoryinMB or CoresPerSocket is supplies)
    Int Total number of cores.

    .PARAMETER ConnectionServerFQDN
    Mandatory: yes
    FQDN of the connectionserver to connect to i.e. server.domain.dom

    .PARAMETER SinceDate
    Mandatory: yes
    Datetime object for the earliest date to get events for

    .PARAMETER AuditSeverityTypes
    Mandatory: No
    Array with severity types to get events for. Allowed entries are: INFO,WARNING,ERROR,AUDIT_SUCCESS,AUDIT_FAIL,UNKNOWN

    .EXAMPLE
    .\Horizon_Rest_Get_Events.ps1 -ConnectionServerFQDN pod1cbr1.loft.lab -sincedate (get-date).adddays(-100)
    This will ask the user for credentials and export all event database entries for the last 100 days

    .EXAMPLE
    .\Horizon_Rest_Get_Events.ps1 -ConnectionServerFQDN pod1cbr1.loft.lab -sincedate (get-date).adddays(-100) -auditseveritytypes "ERROR","WARNING"
    This will ask the user for credentials and export all event database entries for the last 100 days where the severity is ERROR or WARNING

    .EXAMPLE
    .\Horizon_Rest_Get_Events.ps1 -ConnectionServerFQDN pod1cbr1.loft.lab -sincedate (get-date).adddays(-100) -Credential $creds -auditseveritytypes "ERROR","WARNING"
    This will use the supplied credentials and get Horizon Event database entries of the ERROR and WARNING type for the last 100 days.


#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $false,
        HelpMessage = 'Credential object as domain\username with password' )]
    [PSCredential] $Credential,
    
    [Parameter(Mandatory = $true, HelpMessage = 'FQDN of the connectionserver' )]
    [ValidateNotNullOrEmpty()]
    [string] $ConnectionServerFQDN,

    [Parameter(Mandatory = $true, HelpMessage = 'Amount of hours to look back for events' )]
    [ValidateNotNullOrEmpty()]
    [datetime]$SinceDate,

    [Parameter(Mandatory = $false, HelpMessage = 'Array of severity types to get events for i.e. "ERROR","INFO"' )]
    [ValidateNotNullOrEmpty()]
    [array]$AuditSeverityTypes
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
function Get-HRHeader() {
    param($accessToken)
    return @{
        'Authorization' = 'Bearer ' + $($accessToken.access_token)
        'Content-Type'  = "application/json"
    }
}

function Open-HRConnection() {
    param(
        [string] $username,
        [string] $password,
        [string] $domain,
        [string] $url
    )

    $Credentials = New-Object psobject -Property @{
        username = $username
        password = $password
        domain   = $domain
    }

    return invoke-restmethod -Method Post -uri "$url/rest/login" -ContentType "application/json" -Body ($Credentials | ConvertTo-Json)
}

function Close-HRConnection() {
    param(
        $refreshToken,
        $url
    )
    return Invoke-RestMethod -Method post -uri "$url/rest/logout" -ContentType "application/json" -Body ($refreshToken | ConvertTo-Json)
}

function Get-HorizonRestData() {
    [CmdletBinding(DefaultParametersetName = 'None')] 
    param(
        [Parameter(Mandatory = $true,
            HelpMessage = 'url to the server i.e. https://pod1cbr1.loft.lab' )]
        [string] $ServerURL,

        [Parameter(Mandatory = $true,
            ParameterSetName = "filteringandpagination",
            HelpMessage = 'Array of ordered hashtables' )]
        [array] $filters,

        [Parameter(Mandatory = $true,
            ParameterSetName = "filteringandpagination",
            HelpMessage = 'Type of filter Options: And, Or' )]
        [ValidateSet('And', 'Or')]
        [string] $Filtertype,

        [Parameter(Mandatory = $false,
            ParameterSetName = "filteringandpagination",
            HelpMessage = 'Page size, default = 500' )]
        [int] $pagesize = 1000,

        [Parameter(Mandatory = $true,
            HelpMessage = 'Part after the url in the swagger UI i.e. /external/v1/ad-users-or-groups' )]
        [string] $RestMethod,

        [Parameter(Mandatory = $true,
            HelpMessage = 'Part after the url in the swagger UI i.e. /external/v1/ad-users-or-groups' )]
        [PSCustomObject] $accessToken,

        [Parameter(Mandatory = $false,
            ParameterSetName = "filteringandpagination",
            HelpMessage = '$True for rest methods that contain pagination and filtering, default = False' )]
        [switch] $filteringandpagination,

        [Parameter(Mandatory = $false,
            ParameterSetName = "id",
            HelpMessage = 'To be used with single id based queries like /monitor/v1/connection-servers/{id}' )]
        [string] $id,

        [Parameter(Mandatory = $false,
            HelpMessage = 'Extra additions to the query url that comes before the paging/filtering parts like brokering_pod_id=806ca in /rest/inventory/v1/global-sessions?brokering_pod_id=806ca&page=2&size=100' )]
        [string] $urldetails
    )

    if ($filteringandpagination) {
        if ($filters) {
            $filterhashtable = [ordered]@{}
            $filterhashtable.add('type', $filtertype)
            $filterhashtable.filters = @()
            foreach ($filter in $filters) {
                $filterhashtable.filters += $filter
            }
            $filterflat = $filterhashtable | convertto-json -Compress
            if ($urldetails) {
                $urlstart = $ServerURL + "/rest/" + $RestMethod + "?" + $urldetails + "&filter=" + $filterflat + "&page="
            }
            else {
                $urlstart = $ServerURL + "/rest/" + $RestMethod + "?filter=" + $filterflat + "&page="
            }
        }
        else {
            if ($urldetails) {
                $urlstart = $ServerURL + "/rest/" + $RestMethod + "?" + $urldetails + "&page="
            }
            else {
                $urlstart = $ServerURL + "/rest/" + $RestMethod + "?page="
            }
        }
        $results = [System.Collections.ArrayList]@()
        $page = 1
        $uri = $urlstart + $page + "&size=$pagesize"
        $response = Invoke-webrequest $uri -Method 'GET' -Headers (Get-HRHeader -accessToken $accessToken)
        $data = $response.content | convertfrom-json
        $responseheader = $response.headers
        $data.foreach({ $results.add($_) }) | out-null
        if ($responseheader.HAS_MORE_RECORDS -contains "TRUE") {
            do {
                $page++
                $uri = $urlstart + $page + "&size=$pagesize"
                $response = Invoke-webrequest $uri -Method 'GET' -Headers (Get-HRHeader -accessToken $accessToken) 
                $data = $response.content | convertfrom-json
                $responseheader = $response.headers
                $data.foreach({ $results.add($_) }) | out-null
            } until ($responseheader.HAS_MORE_RECORDS -notcontains "TRUE")
        }
    }
    elseif ($id) {
        $uri = $ServerURL + "/rest/" + $RestMethod + "/" + $id
        $data = Invoke-webrequest $uri -Method 'GET' -Headers (Get-HRHeader -accessToken $accessToken)
        $results = $data.content | convertfrom-json
    }
    else {
        if ($urldetails) {
            $uri = $ServerURL + "/rest/" + $RestMethod + "?" + $urldetails
        }
        else {
            $uri = $ServerURL + "/rest/" + $RestMethod
        }
        $data = Invoke-webrequest $uri -Method 'GET' -Headers (Get-HRHeader -accessToken $accessToken)
        $results = $data.content | convertfrom-json
    }

    return $results
}

# this is needed to ignore invalid certificates

Add-Type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(
    ServicePoint srvPoint, X509Certificate certificate,
    WebRequest request, int certificateProblem) {
        return true;
    }
}
"@

[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

# Set Tls versions
$allProtocols = [System.Net.SecurityProtocolType]'Ssl3,Tls,Tls11,Tls12'
[System.Net.ServicePointManager]::SecurityProtocol = $allProtocols

# Get the stored credentials for running the script
if ($Credential) {
    $creds = $credential
}
else {
    $creds = get-credential
}

$date = get-date

$nowepoch = ([DateTimeOffset]$date).ToUnixTimeMilliseconds()
$thenepoch = ([DateTimeOffset]$sinceDate).ToUnixTimeMilliseconds()

# $epoch = ([DateTimeOffset]$starttime).ToUnixTimeMilliseconds()

$username = ($creds.GetNetworkCredential()).userName
$domain = ($creds.GetNetworkCredential()).Domain
$UnsecurePassword = ($creds.GetNetworkCredential()).password

$url = "https://$ConnectionServerFQDN"

$login_tokens = Open-HRConnection -username $username -password $UnsecurePassword -domain $Domain -url $url
$AccessToken = $login_tokens | Select-Object Access_token
$RefreshToken = $login_tokens | Select-Object Refresh_token

$auditevents = @()

if ($auditseveritytypes) {
    foreach ($audittype in $auditseveritytypes) {
        $auditfilters = @()
        $timefilter = [ordered]@{}
        $timefilter.add('type', 'Between')
        $timefilter.add('name', 'time')
        $timefilter.add('fromValue', $thenepoch)
        $timefilter.add('toValue', $nowepoch)
        $auditfilters += $timefilter
        $auditfilter = [ordered]@{}
        $auditfilter.add('type', 'Equals')
        $auditfilter.add('name', 'severity')
        $auditfilter.add('value', $audittype)
        $auditfilters += $auditfilter
        $rawauditevents += Get-HorizonRestData -ServerURL $url -RestMethod "/external/v1/audit-events" -accessToken $accessToken -filteringandpagination -Filtertype "And" -filters $auditfilters
    }
}
else {
    $auditfilters = @()
    $timefilter = [ordered]@{}
    $timefilter.add('type', 'Between')
    $timefilter.add('name', 'time')
    $timefilter.add('fromValue', $thenepoch)
    $timefilter.add('toValue', $nowepoch)
    $auditfilters += $timefilter
    $rawauditevents = Get-HorizonRestData -ServerURL $url -RestMethod "/external/v1/audit-events" -accessToken $accessToken -filteringandpagination -Filtertype "And" -filters $auditfilters
}
$rawauditevents = $rawauditevents | sort-object time -desc

$auditevents = New-Object System.Collections.ArrayList
foreach ($event in $rawauditevents) {
    $readabletimestamp = ([datetimeoffset]::FromUnixTimeMilliseconds(($event).Time)).ToLocalTime()
    $readabletimestamputc = [datetimeoffset]::FromUnixTimeMilliseconds(($event).Time)
    $timeepoch = $event.time
    $event.psobject.Properties.Remove('Time')
    $event | Add-Member -MemberType NoteProperty -Name time -Value $readabletimestamp
    $event | Add-Member -MemberType NoteProperty -Name time_utc -Value $readabletimestamputc
    $event | Add-Member -MemberType NoteProperty -Name time_epoch -Value $timeepoch
    $auditevents.add($event) | out-null
}

return $auditevents

Close-HRConnection -refreshToken $RefreshToken -url $url