$hvserver1=connect-hvserver connectionservername
$services1=$hvserver1.extensiondata
$machinename="machinename"
$machineid=(get-hvmachine -machinename $machinename).id
$machineservice=new-object vmware.hv.machineservice
$machineinfohelper=$machineservice.read($services1, $machineid)
$machineinfohelper.getbasehelper().setuser($null)
$machineservice.update($services1, $machineinfohelper)
