#-------------------------------------------------
# Generates a clean Host Profile
#
# Build using PowerCLI 11
#
# Version 1.0
# 17-08-2019
# Created by: Wouter Kursten
# Website: https://www.retouw.nl
#
#-------------------------------------------------

param(
[Parameter(Mandatory=$true)][String]$Hostprofilename,
[Parameter(Mandatory=$true)][String]$vcenter,
[Parameter(Mandatory=$true)][String]$referencehost,
[Parameter()][String]$dnshost,
[Parameter()][String]$domainname,
[Parameter()][bool]$Cleanup = $false
)

# I grabbed this function somewhere from an example by Luc Dekens
function Copy-Property ($From, $To, $PropertyName ="*"){
    foreach ($p in Get-Member -In $From -MemberType Property -Name $propertyName){
        trap {
            Add-Member -In $To -MemberType NoteProperty -Name $p.Name -Value $From.$($p.Name) -Force
            continue
        }
    $To.$($P.Name) = $From.$($P.Name)
    }
}

#connect to the vCenter
connect-viserver $vcenter

# This deletes any existing Host Profile with the same name as we're using in this script
get-vmhostprofile -name $Hostprofilename  -ErrorAction SilentlyContinue | Remove-VMHostProfile -Confirm:$false

# This creates a new Host Profile from the referencehost
new-vmhostprofile -name $Hostprofilename -referencehost $referencehost

# Retrieves the newly created Host Profile
$hp = Get-VMHostProfile -Name $Hostprofilename

# Creates the spec where the cleanup is done
$spec = New-Object VMware.Vim.HostProfileCompleteConfigSpec

# Copies all properties of the new Host Profile to the spec
Copy-Property -From $hp.ExtensionData.Config -To $spec

# This removes everything that could be specific to the referencehost
if ($cleanup -eq $true){
    $spec.ApplyProfile.Network.Vswitch=$null
    $spec.ApplyProfile.Network.VMportgroup=$null
    $spec.ApplyProfile.Network.HostPortGroup=$null
    $spec.ApplyProfile.Network.pnic=$null
    $spec.ApplyProfile.Storage.NasStorage=$null
    ($spec.ApplyProfile.Property | where-object {$_.PropertyName -like "*DeviceAlias*"}).profile=$null
    ($spec.ApplyProfile.Property | where-object {$_.PropertyName -like "*PCI*"}).profile.property.profile=$null
}

# From here it's just disabling of items except for:
# -items under storage> PSA Configuration (profiles are removed)
# -Properties of the fixed DNS config (set to the default values from this scripts parameters)
$spec.ApplyProfile.Datetime.Enabled=$False
$spec.ApplyProfile.Authentication.Enabled=$False
$spec.ApplyProfile.Authentication.ActiveDirectory.Enabled=$False

foreach ($o in $spec.applyprofile.Option){
    if ($o.Enabled){
        $o.Enabled=$False
    }
}

foreach ($p in $spec.ApplyProfile.Property.Profile){
    if ($p.Enabled){
        $p.Enabled=$False
    }
    foreach ($pa in $p.Property.Profile){
            if ($pa.Enabled){
                $pa.Enabled=$False
                }
        foreach ($paa in $pa.Property.Profile){
                if ($paa.Enabled){
                    $paa.Enabled=$False
                }
        }
    }
}

foreach ($s in $spec.ApplyProfile.Storage.Nasstorage){
    if ($s.Enabled){
        $s.Enabled=$False
    }
    foreach ($sa in $s){
        if ($sa.Enabled){
            $sa.Enabled=$False
        }
    }
}

foreach ($s in $spec.ApplyProfile.Storage.Property.Profile){
    if ($s.Enabled){
        $s.Enabled=$False
    }

    if ($s.ProfileTypeName -eq "psa_psaProfile_PluggableStorageArchitectureProfile" -AND $cleanup -eq $true){
        foreach ($sa in $s.property){
            if ($sa.propertyname -like "*psa_psaProfile_PsaDevice*"){
                $sa.profile=@()
            }
        }
    }
    foreach ($sa in $s.Property.Profile){
        if ($sa.Enabled){
            $sa.Enabled=$False
            }
        foreach ($saa in $sa.Property.Profile){
            if ($saa.Enabled){
                $saa.Enabled=$False
            }
        }
    }
}

foreach ($f in $spec.ApplyProfile.Firewall.ruleset){
    if ($f.Enabled){
        $f.Enabled=$False
    }
}

foreach ($n in $spec.ApplyProfile.Network.vswitch){
    if ($n.Enabled){
        $n.Enabled=$False
    }
    foreach ($na in $n){
        if ($na.Enabled){
            $na.Enabled=$False
        }
        foreach ($naa in $na.link){
            if ($naa.enabled -eq $True){
                $naa.Enabled=$False
            }
        }
        foreach ($naa in $na.NumPorts){
            if ($naa.enabled -eq $True){
                $naa.Enabled=$False
            }
        }
        foreach ($naa in $na.NetworkPolicy){
            if ($naa.enabled -eq $True){
                $naa.Enabled=$False
            }
        }
    }
}

foreach ($n in $spec.ApplyProfile.Network.pnic){
    if ($n.Enabled){
        $n.Enabled=$False
    }
    foreach ($na in $n){
        if ($na.Enabled){
            $na.Enabled=$False
        }
    }
}

foreach ($n in $spec.ApplyProfile.Network.VmPortGroup){
    if ($n.Enabled){
        $n.Enabled=$False
    }
    foreach ($na in $n){
        if ($na.Enabled){
            $na.Enabled=$False
        }
        foreach ($naa in $na.Vlan){
            if ($naa.enabled -eq $True){
                $naa.Enabled=$False
            }
        }
        foreach ($naa in $na.Vswitch){
            if ($naa.enabled -eq $True){
                $naa.Enabled=$False
            }
        }
        foreach ($naa in $na.NetworkPolicy){
            if ($naa.enabled -eq $True){
                $naa.Enabled=$False
            }
        }
    }
}

foreach ($n in $spec.ApplyProfile.Network.HostPortGroup){
    if ($n.Enabled){
        $n.Enabled=$False
    }
    foreach ($na in $n){
        if ($na.Enabled){
            $na.Enabled=$False
        }
        foreach ($naa in $na.IpConfig){
            if ($naa.enabled -eq $True){
                $naa.Enabled=$False
            }
        }
        foreach ($naa in $na.Vlan){
            if ($naa.enabled -eq $True){
                $naa.Enabled=$False
            }
        }
        foreach ($naa in $na.Vswitch){
            if ($naa.enabled -eq $True){
                $naa.Enabled=$False
            }
        }
        foreach ($naa in $na.NetworkPolicy){
            if ($naa.enabled -eq $True){
                $naa.Enabled=$False
            }
        }
    }
}

foreach ($n in $spec.ApplyProfile.Network.Property.Profile){
    if ($n.Enabled){
        $n.Enabled=$False
    }
    foreach ($na in $n.Property.Profile){
        if ($na.Enabled){
            $na.Enabled=$False
            }
        foreach ($np in $na.policy.policyoption){
            if ($np.id -eq "FixedDnsConfig"){
                foreach ($npp in $np.parameter){
                    if ($dnshost){
                        if ($npp.key -eq "address") {
                            [string[]]$dnsarray=@($dnshost)
                            $npp.value=$dnsarray
                        }
                    }
                    if ($domainname){
                        if ($npp.key -eq "domainName"){
                            $npp.value=$domainname
                        }
                    }
                }
            }
        }
        foreach ($naa in $na.Property.Profile){
            if ($naa.Enabled){
                $naa.Enabled=$False
            }
            foreach ($naaa in $naa.Property.Profile){
                if ($naaa.Enabled){
                    $naaa.Enabled=$False
                }
            }
        }
    }
}


(Get-VMHostProfile $Hostprofilename).ExtensionData.Updatehostprofile($spec)
disconnect-viserver $vcenter -confirm:$False