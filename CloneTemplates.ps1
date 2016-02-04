<#
.SYNOPSIS

.DESCRIPTION
Automates the process of cloning out a base template to multiple clones in specific folders with specific networks setup.

.PARAMETER
-vcenter
    The target vcenter to connect to
-datacenter
    The target datacenter to work/search within
-cluster
    The cluster in which to deploy the cloned templates
-templateDS
    The name of the datastore you want to put the template clones into
-credPath
    The path to the VICredentialStore file that contains the necessary credentials to connect to vCenter and each ESXi host directly
-csvFile
    The file that contains all the details of the TemplateSource, TemplateName, NetworkName, DestinationPath

.EXAMPLE
.\CloneTemplates.ps1 -vcenter wclabvcenter01.itlab.local -datacenter 'Datacenter Name' -cluster 'Cluster String' -templateDS 'DATASTORE NAME' -credPath 'c:\temp\mycredentails.xml' -csvFile 'c:\temp\templates.csv'
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
    [String]$templateDS=$null,
    # Credential File Path
    [String]$credPath = "",
	# Credential File Path
    [String]$csvFile = ""
)
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
	$goldenTemp = $clone.TemplateSource
	$newTempName = $clone.TemplateName
	$newNetworkName = $clone.NetworkName
	$vmFolder = $clone.DestinationPath
	
    Write-Host $vmFolder.Length

	if($vmFolder.Length -gt 0){
		$destFolder = Get-FolderFromPath($vmFolder)
		if($destFolder -eq $null){
		    Write-Host "ERROR: $vmFolder Path NOT FOUND!  Halting."
		    Break
		}
	}else{
        Write-Host "DestinationPath " + $vmFolder.Length
		Write-Host "ERROR: DestinationPath NOT SPECIFIED IN CSV!  Halting."
        break;
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