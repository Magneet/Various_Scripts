$icausername=read-host "What username to use for instantclone administrator?"
$icadomain=read-host "please give the dns name for the domain to user (i.e. domain.com)"
$icapassword=read-host "vCenter User password?" -assecurestring
$temppw = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($icaPassword)
$PlainicaPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($temppw)
$icadminPassword = New-Object VMware.Hv.SecureString
$enc = [system.Text.Encoding]::UTF8
$icadminPassword.Utf8String = $enc.GetBytes($PlainicaPassword)
$spec=new-object vmware.hv.InstantCloneEngineDomainAdministratorSpec
$spec.base=new-object vmware.hv.InstantCloneEngineDomainAdministratorBase
$spec.base.domain=(($services1.ADDomain.addomain_list() | where {$_.DnsName -eq $icadomain} | select-object -first 1).id)
$spec.base.username=$icausername
$spec.base.password=$icadminpassword
$services1.InstantCloneEngineDomainAdministrator.InstantCloneEngineDomainAdministrator_Create($spec)
