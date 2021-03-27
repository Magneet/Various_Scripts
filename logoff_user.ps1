function get-disconnectsession {

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)][string]$TargetUser,
        [Parameter(Mandatory)][string]$TargetMachine,
        [Parameter(Mandatory)][string]$HVSrv
    )

    $hvserver1 = Connect-HVServer -Server $HVSrv -Credential $VMWareAuth
    $Services1 = $hvServer1.ExtensionData

    $queryService = New-Object VMware.Hv.QueryServiceService
    $sessionfilterspec = New-Object VMware.Hv.QueryDefinition
    $sessionfilterspec.queryEntityType = 'SessionLocalSummaryView'
    $sessionfilter1 = New-Object VMware.Hv.QueryFilterEquals
    $sessionfilter1.membername = 'namesData.userName'
    $sessionfilter1.value = $TargetUser
    $sessionfilter2 = New-Object VMware.Hv.QueryFilterEquals
    $sessionfilter2.membername = 'namesData.machineOrRDSServerDNS'
    $sessionfilter2.value = $TargetMachine
    $sessionfilter = new-object vmware.hv.QueryFilterAnd
    $sessionfilter.filters = @($sessionfilter1, $sessionfilter2)
    $sessionfilterspec.filter = $sessionfilter
    $session = ($queryService.QueryService_Create($Services1, $sessionfilterspec)).results
    $queryService.QueryService_DeleteAll($services1)
    if ($session.count -eq 0) {
        Show-UDToast -Message "No session found for $targetuser on $targetmachine" -MessageColor 'red' -Theme 'light' -TransitionIn 'bounceInUp' -CloseOnClick -Position center -Duration 2000
        break
    }
    else {
        try {
            $Services1.Session.Session_Logoffforced($session.id)
        }
        catch {
            Show-UDToast -Message "Error logging user off" -MessageColor 'red' -Theme 'light' -TransitionIn 'bounceInUp' -CloseOnClick -Position center -Duration 2000
        }
    }
}
