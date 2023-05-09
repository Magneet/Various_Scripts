$url = "https://pod1cbr1.loft.lab"

$credentials = Import-Clixml .\creds.xml
$username = ($credentials.username).split("\")[1]
$domain = ($credentials.username).split("\")[0]
$password = $credentials.password

$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password) 
$UnsecurePassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)


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
        $accessToken,
        $url
    )
    return Invoke-RestMethod -Method post -uri "$url/rest/logout" -ContentType "application/json" -Body ($accessToken | ConvertTo-Json)
}

$accessToken = Open-HRConnection -username $username -password $UnsecurePassword -domain $Domain -url $url

$pools = Invoke-RestMethod -Method Get -uri "$url/rest/inventory/v5/desktop-pools" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)
$poolid = ($pools | where-object { $_.name -eq "vmug_demo_pool2" }).id
$pool = Invoke-RestMethod -Method Get -uri "$url/rest/inventory/v5/desktop-pools/$poolid" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken)
$pool.display_protocol_settings.psobject.properties.remove("display_protocols")
$pool.display_protocol_settings.psobject.properties.remove("html_access_enabled")
$pool.display_protocol_settings.psobject.properties.remove("grid_vgpus_enabled")
$pool.view_storage_accelerator_settings.psobject.properties.remove("add_virtual_tpm")
$pool.view_storage_accelerator_settings.psobject.properties.remove("view_storage_accelerator_disk_types")
$pool.view_storage_accelerator_settings.psobject.properties.remove("regenerate_view_storage_accelerator_days")
$pool.provisioning_settings.psobject.properties.remove("min_ready_vms_on_vcomposer_maintenance")
$pool.provisioning_settings.psobject.properties.remove("add_virtual_tpm")
$pool.provisioning_settings.psobject.properties.remove("parent_vm_id")
$pool.provisioning_settings.psobject.properties.remove("base_snapshot_id")
$pool.provisioning_settings.psobject.properties.remove("datacenter_id")
$pool.provisioning_settings.psobject.properties.remove("vm_folder_id")
$pool.storage_settings.datastores | foreach { $_.psobject.properties.remove("storage_overcommit") }
$pool.storage_settings.datastores | foreach { $_.psobject.properties.remove("sdrs_cluster") }
$pool.storage_settings.psobject.properties.remove("use_native_snapshots")
$pool.storage_settings.psobject.properties.remove("redirect_windows_profile")
$pool.storage_settings.psobject.properties.remove("use_separate_datastores_persistent_and_os_disks")
$pool.storage_settings.psobject.properties.remove("non_persistent_redirect_disposable_files")
$pool.storage_settings.psobject.properties.remove("reclaim_vm_disk_space")
$pool.session_settings.psobject.properties.remove("refresh_os_disk_after_logoff")

$json = $pool | select-object -excludeproperty allow_rds_pool_multi_session_per_user, automatic_user_assignment, id, name, delete_in_progress, type, source, image_source, vcenter_id, user_assignment, provisioning_status_data, user_group_count, naming_method |  ConvertTo-Json -Depth 100
Invoke-RestMethod -Method Put -uri "$url/rest/inventory/v1/desktop-pools/$poolid" -ContentType "application/json" -Headers (Get-HRHeader -accessToken $accessToken) -body $json
