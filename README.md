# vSphere-Clone-Templates
Automates the process of cloning out a base template to multiple clones in specific folders with specific networks setup.

**Tested With**
- Powershell 4
- PowerCLI 6.0
- vSphere 5.5, 6.0

**Configuration**
Create a VICredentialStore with credentials for your vcenter server and credentials for every ESXi server in the cluster.

**PowerCLI commands to create the VICredentialStore file.**

Passwords are hashed but are reversable.  Rights to the file are restricted to the user who creates the file
```
New-VICredentialStoreItem -Host <vcenter_name> -User <user_name> -Password <password> -File 'c:\Path\To\Credential\File.xml'
New-VICredentialStoreItem -Host <esxi_server_01> -User <user_name> -Password <password> -File 'c:\Path\To\Credential\File.xml'
New-VICredentialStoreItem -Host <esxi_server_02> -User <user_name> -Password <password> -File 'c:\Path\To\Credential\File.xml'
New-VICredentialStoreItem -Host <esxi_server_XX> -User <user_name> -Password <password> -File 'c:\Path\To\Credential\File.xml'
```

**Parameters**
```
PARAMETER
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
```

#####EXAMPLE
```
.\CloneTemplates.ps1 -vcenter vcenterFQDN -datacenter 'Datacenter Name' -cluster 'Cluster String' -templateDS 'DATASTORE NAME' -credPath 'c:\temp\mycredentails.xml' -csvFile 'c:\temp\templates.csv'
```
