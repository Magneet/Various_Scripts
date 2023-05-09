[CmdletBinding()]
param (
    [parameter(Mandatory = $true,
        HelpMessage = "Default location where csv's will be exported to.")]
    [string]$sourcefile,
    [parameter(Mandatory = $true,
        HelpMessage = "Default location where csv's will be exported to.")]
    [string]$Exportfile
)

$data = (get-content $sourcefile | convertfrom-json).paths.psobject.properties
[array]$list = @()
foreach ($path in $data) {
    $name = $path.name
    $methods = ($path.value | Get-Member -membertype properties).name
    foreach ($method in $methods) {
        $obj = [PSCustomObject]@{
            Name   = $name
            method = $method
        }
        $list += $obj
    }
}
$list | export-csv $exportfile