[CmdletBinding()]
param (
    [Parameter(Mandatory = $false,
        HelpMessage = 'Credential object as domain\username with password' )]
    [PSCredential] $Credential,
    
    [Parameter(Mandatory = $true, HelpMessage = 'FQDN of the connectionserver' )]
    [ValidateNotNullOrEmpty()]
    [string] $ConnectionServerFQDN,

    [Parameter(Mandatory = $true, HelpMessage = 'Treshold for Events to trigger on' )]
    [ValidateNotNullOrEmpty()]
    [int]$event_treshold,
            
    [Parameter(Mandatory = $true, HelpMessage = 'Amount of hours to look back for events' )]
    [ValidateNotNullOrEmpty()]
    [int]$hoursback
)
$ErrorActionPreference = 'Stop'

function Get-CUStoredCredential {
    param (
        [parameter(Mandatory = $true,
            HelpMessage = "The system the credentials will be used for.")]
        [string]$System
    )

    # Get the stored credential object
    $strCUCredFolder = "$([environment]::GetFolderPath('CommonApplicationData'))\ControlUp\ScriptSupport"
    try {
        Import-Clixml -LiteralPath $strCUCredFolder\$($env:USERNAME)_$($System)_Cred.xml
    }
    catch {
        write-error $_
    }
}


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

    return invoke-restmethod -Method Post -uri "$url/rest/login" -ContentType "application/json" -Body ($Credentials | ConvertTo-Json) -SkipCertificateCheck
}

function Close-HRConnection() {
    param(
        $refreshToken,
        $url
    )
    return Invoke-RestMethod -Method post -uri "$url/rest/logout" -ContentType "application/json" -Body ($refreshToken | ConvertTo-Json) -SkipCertificateCheck
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
        [int] $pagesize = 500,

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
        $response = Invoke-RestMethod $uri -Method 'GET' -Headers (Get-HRHeader -accessToken $accessToken) -SkipCertificateCheck
        $response.foreach({ $results.add($_) }) | out-null
        if ($responseheader.HAS_MORE_RECORDS -contains "TRUE") {
            do {
                $page++
                $uri = $urlstart + $page + "&size=$pagesize"
                $response = Invoke-RestMethod $uri -Method 'GET' -Headers (Get-HRHeader -accessToken $accessToken) -SkipCertificateCheck
                $response.foreach({ $results.add($_) }) | out-null
            } until ($responseheader.HAS_MORE_RECORDS -notcontains "TRUE")
        }
    }
    elseif ($id) {
        $uri = $ServerURL + "/rest/" + $RestMethod + "/" + $id
        $results = Invoke-RestMethod $uri -Method 'GET' -Headers (Get-HRHeader -accessToken $accessToken) -SkipCertificateCheck
    }
    else {
        if ($urldetails) {
            $uri = $ServerURL + "/rest/" + $RestMethod + "?" + $urldetails
        }
        else {
            $uri = $ServerURL + "/rest/" + $RestMethod
        }
        
        $results = Invoke-RestMethod $uri -Method 'GET' -Headers (Get-HRHeader -accessToken $accessToken) -SkipCertificateCheck
    }

    return $results
}

function Get-Pods() {
    [CmdletBinding(DefaultParametersetName = 'None')] 
    param(
        [Parameter(Mandatory = $true,
            HelpMessage = 'url to the server i.e. https://pod1cbr1.loft.lab' )]
        [string] $ServerURL,

        [Parameter(Mandatory = $true,
            HelpMessage = 'Part after the url in the swagger UI i.e. /external/v1/ad-users-or-groups' )]
        [PSCustomObject] $accessToken
    )

    try {
        $results = Get-HorizonRestData -ServerURL $url -RestMethod "/federation/v1/pods" -accessToken $accessToken
    }
    catch {
        throw $_
    }
    return $results
}

# Get the stored credentials for running the script
try {
    [PSCredential]$CredsHorizon = Get-CUStoredCredential -System 'HorizonView'
}
catch {
    $CredsHorizon = get-credential
}

$ErrorActionPreference = 'Stop'


$date = get-date

$sinceDate = (get-date).AddHours(-$hoursback)
$nowepoch = ([DateTimeOffset]$date).ToUnixTimeMilliseconds()
$thenepoch = ([DateTimeOffset]$sinceDate).ToUnixTimeMilliseconds()

# $epoch = ([DateTimeOffset]$starttime).ToUnixTimeMilliseconds()


$username = ($CredsHorizon.username).split("\")[1]
$domain = ($CredsHorizon.username).split("\")[0]
$password = $CredsHorizon.password

$url = "https://$ConnectionServerFQDN"

$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password) 
$UnsecurePassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

$login_tokens = Open-HRConnection -username $username -password $UnsecurePassword -domain $Domain -url $url
$AccessToken = $login_tokens | Select-Object Access_token
$RefreshToken = $login_tokens | Select-Object Refresh_token
[array]$audittypes = "WARNING", "ERROR", "AUDIT_FAIL"
$auditevents = @()

foreach ($audittype in $audittypes) {
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
    $auditevents += Get-HorizonRestData -ServerURL $url -RestMethod "/external/v1/audit-events" -accessToken $accessToken -filteringandpagination -Filtertype "And" -filters $auditfilters
}
$auditevents = $auditevents | sort-object time -desc
return $auditevents


Close-HRConnection -refreshToken $RefreshToken -url $url