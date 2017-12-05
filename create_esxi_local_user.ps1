#-------------------------------------------------
# Create local ESXi user with admin rights and lockdown exception while the host is in lockdown mode
# 
# Requires PowerCLI 6.5 or higher (module based not snappin)
# Based on scripts by Luc Dekens and others
#
# Version 1.0
# 09-10-2017
# Created by: Wouter Kursten
#
#-------------------------------------------------
#
# Load the required VMware modules (for PowerShell only)

Write-Host "Loading VMware PowerCLI Modules" -ForegroundColor Green
try	{
    get-module -listavailable vm* | import-module -erroraction stop
}
catch	{
    write-host "No Powercli found" -ForegroundColor Red
}

#Ask for connection information

$vcenter=Read-Host "Enter vCenter server name"
$Target = Read-Host "Which hosts? (i.e. server*)"
$rootpassword = Read-Host "Enter root Password" -AsSecureString
$accountName = Read-Host "Enter New Username"
$accountDescription  = Read-Host "Enter New User description"
$accountPswd = Read-Host "Enter New User Password" -AsSecureString
$rootuser="root"

# Connect to vCenter
$connectedvCenter = $global:DefaultVIServer

if($connectedvCenter.name -ne $vcenter){
	Connect-VIServer $vCenter -wa 0 | Out-Null
	Write-Host "Connected"
	Write-Host " "
}

# Get the host inventory from vCenter
$vmhosts = Get-VMHost $Target | Sort Name

foreach($vmhost in $vmhosts){
    try {
        (get-vmhost $vmhost | get-view).ExitLockdownMode()
        write-host "Lockdown disabled for $vmhost" -foregroundcolor green
    }
    catch   {
        write-host "can't disable lockdown for $vmhost maybe it's already disabled" -foregroundcolor Red
    }

    connect-viserver -server $vmhost -user $rootuser -password ([Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($rootpassword))) -wa 0 -notdefault | Out-Null

    Try {
        $account = Get-VMHostAccount -server $vmhost.name -Id $accountName -ErrorAction Stop |
        Set-VMHostAccount -server $vmhost.name -Password ([Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($accountPswd))) -Description $accountDescription 
    }
    Catch   {
        $account = New-VMHostAccount -server $vmhost.name -Id $accountName -Password ([Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($accountPswd))) -Description $accountDescription -UserAccount -GrantShellAccess 
    }
    
    $rootFolder = Get-Folder -server $vmhost.name -Name ha-folder-root
    New-VIPermission -server $vmhost.name -Entity $rootFolder -Principal $account -Role admin

    #Adding the new user to the Lockdown Exceptions list
    $HostAccessManager = Get-View -Server $vCenter $vmhost.ExtensionData.ConfigManager.HostAccessManager
    $HostAccessManager.UpdateLockdownExceptions($accountName)
     
      
    Disconnect-VIServer $vmhost.name -Confirm:$false  
    try {	
        (get-vmhost $vmhost | get-view).EnterLockdownMode()
        write-host "Lockdown enabled for $vmhost" -foregroundcolor green
    }
    catch   {
        write-host "can't disable lockdown for $vmhost maybe it's already Enabled?" -foregroundcolor Red}
    }
}

    Disconnect-VIServer -Confirm:$false
