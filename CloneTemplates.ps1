<#
.SYNOPSIS

.DESCRIPTION
Creates an HTML file with direct VMRC links for VMware VMs located in vCenter.  It is meant to provide the ability to console to a VM when vCenter is offline during maintenance.

.PARAMETER
-vcenter
    The target vcenter to connect to
-datacenter
    The target datacenter to work/search within
-cluster
    The cluster in which to deploy the cloned templates
-vmFolder
    [Optional] The folder path to the VMs you want to create VMRC links.  If not defined will provide links for all VMs in the defined Cluster
-credPath
    The path to the VICredentialStore file that contains the necessary credentials to connect to vCenter and each ESXi host directly
-outFile
    The file path to where you want the output stored

.EXAMPLE
GenerateLinks -vcenter yourvcenterserver.domain.local -datacenter 'Datacenter Name' -cluster 'Cluster String' -vmFolder 'Servers\Windows 2003' -credPath 'c:\temp\mycredentails.xml' -outFile 'c:\temp\vmrclinks.html'
#>

############# GLOBALS ##############
param(
    # Vcenter containing the VMs you're interested in
    [String]$vcenter = "",
    # Datacenter Filter
    [String]$datacenter="",
    # Cluster Filter
    [String]$cluster="",
    # Folder path containing VMs you want to create direct VMRC links for
    #$vmFolder="NetLok\Custom VPN's"
    [String]$templateDS=$null,
    # Credential File Path
    [String]$credPath = "",
	# Credential File Path
    [String]$csvFile = ""
)
############# END GLOBALS ##########

############# GLOBALS ##############
# Datacenter to work from
#$datacenter="WC IT LAB"

# Cluster Name
#$cluster="WC IT LAB"

# Template datastore
#$templateDS="WCLABIT_DEPLOY"

# Golden template to work off of
$goldenTemp="WIN2012R2_BASE"

############# END GLOBALS ##########

# Check if VMware PowerCLI is loaded
if((Get-PSSnapin VMware.VimAutomation.Core -ErrorAction SilentlyContinue) -eq $null)
{
    # Since not loaded, try loading it
	Add-PSSnapin VMware.VimAutomation.Core
    if((Get-PSSnapin VMware.VimAutomation.Core -ErrorAction SilentlyContinue) -eq $null){
        Write-Host "ERROR: Unable to load VMware PowerCLI"
        Break
    }
}

# Resolve folder path to Folder Object based on the path
function Get-FolderFromPath
{
    param(
        [String] $Path
    )
    $chunks = $Path.Split('\')
    $root = Get-View -VIObject (Get-Folder -Name $chunks[0])
    if (-not $?){return}
 
    $chunks[1..$chunks.Count] | % {
        $chunk = $_
        $child = $root.ChildEntity | ? {$_.Type -eq 'Folder'} | ? { (Get-Folder -id ("{0}-{1}" -f ($_.Type, $_.Value))).Name -eq $chunk}
        if ($child -eq $null) { throw "Folder '$chunk' not found"}
        $root = Get-View -VIObject (Get-Folder -Id ("{0}-{1}" -f ($child.Type, $child.Value)))
        if (-not $?){return}
    }
    return (Get-Folder -Id ("{0}-{1}" -f ($root.MoRef.Type, $root.MoRef.Value)))
}

##### BASE SETUP ####
# Read in the CSV with the defined columns below
# TemplateSource, TemplateName, NetworkName, DestinationPath
$clones = Import-Csv $csvFile

# Get the credential from the file
$credential = Get-VICredentialStoreItem -Host $vcenter -File $credPath


# Connect to vCenter
Connect-VIServer -Server $vcenter -User $credential.User -Password $credential.Password

$vmHost = Get-Cluster -Name $cluster | Get-VMHost | Select -first 1
##### END BASE SETUP #####

############# SCRIPT ###############

ForEach($clone in $clones){
	$newTempName = $clone.TemplateName
	$newNetworkName = $clone.NetworkName
	$vmFolder = $clone.DestinationPath
	
	if($vmFolder.Length > 0){
		$destFolder = Get-FolderFromPath($vmFolder)
		if($destFolder -eq $null){
		    Write-Host "ERROR: $vmFolder Path NOT FOUND!  Halting."
		    Break
		}
	}else{
		Write-Host "ERROR: $vmFolder Path NOT SPECIFIED IN CSV!  Halting."
	}
	
	# Get Datastore by String
	$destDS=Get-Datastore -Name $templateDS -Datacenter $datacenter

	# Clone template to new VM
	New-VM -Name $newTempName -Template $goldenTemp -Datastore $destDS -VMHost $vmHost -Location $destFolder

	$newVM = Get-VM -Name $newTempName

	# Change the first Network Adapter to correct network
	Get-NetworkAdapter -VM $newVM | Where Name -eq "Network adapter 1" | Set-NetworkAdapter -NetworkName $newNetworkName -Confirm:$false

	# Set VM as Template
	Set-VM -VM $newVM -ToTemplate -Name $newTempName -Confirm:$false
}