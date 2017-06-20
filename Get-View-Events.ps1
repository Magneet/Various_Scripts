#-------------------------------------------------
# Get the Horizon view event for the last x time and export to a csv
#
# Requires PowerCLI 6.5 or higher
# Requires vmware.hv.helper module
# Module can be found at https://github.com/vmware/PowerCLI-Example-Scripts
#
# Version 1.0
# 16-06-2017
# Created by: Wouter Kursten
#
#-------------------------------------------------

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

$hvservername=Read-host "Welke Connection broker?"
$domain=read-host "Please enter your active directory domain?"
$username=Read-host "Please enter your useraccount"
$password=Read-host -assecurestring "Please enter your password"

#Connect to View Connection broker
write-host "Connecting to the connection broker" -ForegroundColor Green
try {
$hvserver=connect-hvserver $hvservername -domain $domain -username $username -password $password -WarningAction silentlyContinue -erroraction stop
}
catch {
	Write-host "Can't connect to the Connection server please check the credentials." -ForegroundColor Red
	exit
	}

#connect to the Event Database

$dbpassword=Read-host -assecurestring "Please enter the password of the account configured in Horizon View to access the event database."
write-host "Connecting to the database" -ForegroundColor Green
try {
	$eventdb=connect-hvevent -dbpassword $dbpassword -erroraction stop
	}
catch {
	Write-host "Can't connect to the Database server please check the password." -ForegroundColor Red
	exit
	}

#Retreive information

write-host "Please provide the following information use % as wildcard." -ForegroundColor Green
$searchuser=Read-Host "Please enter the accountname you need information on?"
$module=Read-Host "What module do you want the logs for? (Agent,Broker,Client,Tunnel,Framework,Client)"
$sevfilter=Read-Host "What is the severity level you need information on?(Audit_fail, Audit_Success,Info,Warning,Error)"
$message=Read-host "Looking for any specific text in the message?"
$maxage=Read-Host "How far do you want to look back in event history? (Day,week,month,all)"
$filelocation=Read-host "Please provide filename and location for the exported csv file"

#Export to file

$lastevent=get-hvevent -hvdbserver $eventdb -timeperiod $maxage -SeverityFilter $sevfilter -userfilter $searchuser -modulefilter $module -messagefilter $message

try {
	$lastevent.events  | export-csv $filelocation -erroraction stop
	}
catch{
	write-host "Unable to create the file, please check name and location" -ForegroundColor Red
	exit
	}
Write-host "Events have been successfully exported." -ForegroundColor Green
