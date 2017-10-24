#-------------------------------------------------
# Remove faulty desktops
# This script has been made to find Horizon VDI desktops in a faulty state.
# The Script will ask for the state you want to check on and then asks for the desktop you want removed.
# For mass removing of desktops a seperate script will be created.
#
# Please be aware that currently get-hvmachine has an output of a maximum of 1000 entries
# 
#
# Menu sourced from https://github.com/rgel/PowerShell/blob/master/MS-Module
# Requires PowerCLI 6.5 or higher
# Requires vmware.hv.helper module
# Module can be found at https://github.com/vmware/PowerCLI-Example-Scripts
#
# Version 1.0
# 20-10-2017
# Created by: Wouter Kursten
#
#-------------------------------------------------




#region menubuilder
Function Write-Menu
{
	
<#
.SYNOPSIS
	Display custom menu in the PowerShell console.
.DESCRIPTION
	The Write-Menu cmdlet creates numbered and colored menues
	in the PS console window and returns the choiced entry.
.PARAMETER Menu
	Menu entries.
.PARAMETER PropertyToShow
	If your menu entries are objects and not the strings
	this is property to show as entry.
.PARAMETER Prompt
	User prompt at the end of the menu.
.PARAMETER Header
	Menu title (optional).
.PARAMETER Shift
	Quantity of <TAB> keys to shift the menu items right.
.PARAMETER TextColor
	Menu text color.
.PARAMETER HeaderColor
	Menu title color.
.PARAMETER AddExit
	Add 'Exit' as very last entry.
.EXAMPLE
	PS C:\> Write-Menu -Menu "Open","Close","Save" -AddExit -Shift 1
	Simple manual menu with 'Exit' entry and 'one-tab' shift.
.EXAMPLE
	PS C:\> Write-Menu -Menu (Get-ChildItem 'C:\Windows\') -Header "`t`t-- File list --`n" -Prompt 'Select any file'
	Folder content dynamic menu with the header and custom prompt.
.EXAMPLE
	PS C:\> Write-Menu -Menu (Get-Service) -Header ":: Services list ::`n" -Prompt 'Select any service' -PropertyToShow DisplayName
	Display local services menu with custom property 'DisplayName'.
.EXAMPLE
	PS C:\> Write-Menu -Menu (Get-Process |select *) -PropertyToShow ProcessName |fl
	Display full info about choicen process.
.INPUTS
	Any type of data (object(s), string(s), number(s), etc).
.OUTPUTS
	[The same type as input object] Single menu item.
.NOTES
	Author      :: Roman Gelman @rgelman75
	Version 1.0 :: 21-Apr-2016 :: [Release]
	Version 1.1 :: 03-Nov-2016 :: [Change] Supports a single item as menu entry
	Version 1.2 :: 22-Jun-2017 :: [Change] Throw an error if property, specified by -PropertyToShow does not exist. Code optimization
.LINK
	https://ps1code.com/2016/04/21/write-menu-powershell
#>
	
	[CmdletBinding()]
	[Alias("menu")]
	Param (
		[Parameter(Mandatory, Position = 0)]
		[Alias("MenuEntry", "List")]
		$Menu
		 ,
		[Parameter(Mandatory = $false, Position = 1)]
		[string]$PropertyToShow = 'Name'
		 ,
		[Parameter(Mandatory = $false, Position = 2)]
		[ValidateNotNullorEmpty()]
		[string]$Prompt = 'Pick a choice'
		 ,
		[Parameter(Mandatory = $false, Position = 3)]
		[Alias("Title")]
		[string]$Header = ''
		 ,
		[Parameter(Mandatory = $false, Position = 4)]
		[ValidateRange(0, 5)]
		[Alias("Tab", "MenuShift")]
		[int]$Shift = 0
		 ,
		[Parameter(Mandatory = $false, Position = 5)]
		[Alias("Color", "MenuColor")]
		[System.ConsoleColor]$TextColor = 'White'
		 ,
		[Parameter(Mandatory = $false, Position = 6)]
		[System.ConsoleColor]$HeaderColor = 'Yellow'
		 ,
		[Parameter(Mandatory = $false)]
		[ValidateNotNullorEmpty()]
		[Alias("Exit", "AllowExit")]
		[switch]$AddExit
	)
	
	Begin
	{
		$ErrorActionPreference = 'Stop'
		if ($Menu -isnot [array]) { $Menu = @($Menu) }
		if ($Menu[0] -isnot [string])
		{
			if (!($Menu | Get-Member -MemberType Property, NoteProperty -Name $PropertyToShow)) { Throw "Property [$PropertyToShow] does not exist" }
		}
		$MaxLength = if ($AddExit) { 8 }
		else { 9 }
		$AddZero = if ($Menu.Length -gt $MaxLength) { $true }
		else { $false }
		[hashtable]$htMenu = @{ }
	}
	Process
	{
		### Write menu header ###
		if ($Header -ne '') { Write-Host $Header -ForegroundColor $HeaderColor }
		
		### Create shift prefix ###
		if ($Shift -gt 0) { $Prefix = [string]"`t" * $Shift }
		
		### Build menu hash table ###
		for ($i = 1; $i -le $Menu.Length; $i++)
		{
			$Key = if ($AddZero)
			{
				$lz = if ($AddExit) { ([string]($Menu.Length + 1)).Length - ([string]$i).Length }
				else { ([string]$Menu.Length).Length - ([string]$i).Length }
				"0" * $lz + "$i"
			}
			else
			{
				"$i"
			}
			
			$htMenu.Add($Key, $Menu[$i - 1])
			
			if ($Menu[$i] -isnot 'string' -and ($Menu[$i - 1].$PropertyToShow))
			{
				Write-Host "$Prefix[$Key] $($Menu[$i - 1].$PropertyToShow)" -ForegroundColor $TextColor
			}
			else
			{
				Write-Host "$Prefix[$Key] $($Menu[$i - 1])" -ForegroundColor $TextColor
			}
		}
		
		### Add 'Exit' row ###
		if ($AddExit)
		{
			[string]$Key = $Menu.Length + 1
			$htMenu.Add($Key, "Exit")
			Write-Host "$Prefix[$Key] Exit" -ForegroundColor $TextColor
		}
		
		### Pick a choice ###
		Do
		{
			$Choice = Read-Host -Prompt $Prompt
			$KeyChoice = if ($AddZero)
			{
				$lz = if ($AddExit) { ([string]($Menu.Length + 1)).Length - $Choice.Length }
				else { ([string]$Menu.Length).Length - $Choice.Length }
				if ($lz -gt 0) { "0" * $lz + "$Choice" }
				else { $Choice }
			}
			else
			{
				$Choice
			}
		}
		Until ($htMenu.ContainsKey($KeyChoice))
	}
	End
	{
		return $htMenu.get_Item($KeyChoice)
	}
	
} 
#EndFunction Write-Menu
#endregion

#region Connection
# Load the required VMware modules (for PowerShell only)

Write-Host "Loading VMware PowerCLI Modules" -ForegroundColor Green
try	{
	get-module -listavailable vm* | import-module -erroraction stop
	}
catch	{
	write-host "No Powercli 6.5 or higher found" -ForegroundColor Red
		}
$version=get-powercliversion -WarningAction silentlyContinue
if ($version.build -lt 4624819)	{
	write-host "Horizon View api's require Powercli 6.5 or higher to function, please upgrade PowerCLI" -ForegroundColor Red
	exit
	}
elseif (get-module vmware.hv.helper  ) {
	write-host "VMware.hv.helper found"
	}
else {
	write-host "Please download and install the VMware.hv.helper module from https://github.com/vmware/PowerCLI-Example-Scripts" -ForegroundColor Red
	exit
	}

#Ask for connection information

$hvservername=Read-host "Which Connection broker do you want to connect to?"
$domain=read-host "Please enter your active directory domain?"
$username=Read-host "Please enter your useraccount"
$password=Read-host -assecurestring "Please enter your password"


#Connect to View Connection broker
write-host "Connecting to the connection broker" -ForegroundColor Green
try {
	$hvserver1=connect-hvserver $hvservername -domain $domain -username $username -password $password -WarningAction silentlyContinue -erroraction stop
	$Services1= $hvServer1.ExtensionData
}
catch {
	Write-host "Can't connect to the Connection server please check the credentials." -ForegroundColor Red
	exit
}
    
#endregion

#region Statemenu

$baseStates = @('PROVISIONING_ERROR',
'ERROR',
'AGENT_UNREACHABLE',
'AGENT_ERR_STARTUP_IN_PROGRESS',
'AGENT_ERR_DISABLED',
'AGENT_ERR_INVALID_IP',
'AGENT_ERR_NEED_REBOOT',
'AGENT_ERR_PROTOCOL_FAILURE',
'AGENT_ERR_DOMAIN_FAILURE',
'AGENT_CONFIG_ERROR',
'MAINTENANCE',
'UNKNOWN')
$targetstate=write-menu -menu $baseStates -header "What connection state do you want to check on?"
#endregion



$spec = New-Object VMware.Hv.machinedeletespec
$spec.deleteFromDisk=$TRUE

$desktops=@()
$desktops=get-hvmachine -state $targetstate
$selectdesktop=@()
foreach ($desktop in $desktops){
    $selectdesktop+= New-Object PSObject -Property @{"Name" = $desktop.base.name
    "ID" = $desktop.id;
    }
}

$selectdesktop=write-menu -menu ($desktops.base.name) -header "Select the desktop you want to remove"
$removedesktop=$desktops | where {$_.base.name -eq $selectdesktop}


try {
	$services1.machine.machine_delete($removedesktop.id, $spec)
	write-host "$selectdesktop are marked for deletion" -ForegroundColor Green
}
catch {
	write-host "Error deleting $selectdesktop" -ForegroundColor Red
}
