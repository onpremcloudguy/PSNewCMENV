function Set-LabSettings {
    #download Adventureworks DB from GitHub and put into the CMServer
    #   - use CMServer SQL Instance to create dummy users
    #process to create x number of workstation clients
    #Download and install SSMS
    #Download and install VSCode
    #process to create x number of dummy clients
    #find a solution to ensure the latest TP is installed
}
    
#endregion
#LAZY MODULE TESTING, WILL BE FIXED ONCE COMPLETED
foreach ($psfile in get-childitem -Filter *.ps1 | Where-Object {$_.name -notin ("newenv.ps1", "NewENV.Tests.ps1")}) {
    . ".\$psfile"
}
    
    
#region import JSON Settings
$scriptpath = $PSScriptRoot
$config = Get-Content "$scriptpath\env.json" -Raw | ConvertFrom-Json
$envConfig = $config.ENVConfig | Where-Object {$_.env -eq $config.env}
$script:logfile = "$($envConfig.vmpath)\Build.log"
if (!(Test-Path $envConfig.vmpath)) {new-item -ItemType Directory -Force -Path $envConfig.vmpath | Out-Null}
Write-LogEntry -Type Information -Message "Start of build process for $($config.env) ------"
$admpwd = $envConfig.AdminPW
Write-LogEntry -Type Information -Message "Admin password set to: $admpwd"
$localadmin = new-object -typename System.Management.Automation.PSCredential -argumentlist "administrator", (ConvertTo-SecureString -String $admpwd -AsPlainText -Force)
$domuser = new-object -typename System.Management.Automation.PSCredential -argumentlist "$($envconfig.env)\administrator", (ConvertTo-SecureString -String $admpwd -AsPlainText -Force)
$vmpath = $envConfig.VMPath
Write-LogEntry -Type Information -Message "Path for VHDXs set to: $vmpath"
$swname = $envConfig.SwitchName
Write-LogEntry -Type Information -Message "vSwitch name is: $swname"
$ipsub = $envConfig.ipsubnet
Write-LogEntry -type Information -Message "IP Subnet used for this lab is: $ipsub"
$DomainFQDN = $envconfig.DomainFQDN
Write-LogEntry -Type Information -Message "Fully Quilified Domain Name is: $domainfqdn"
$RRASname = $Config.RRASname
Write-LogEntry -Type Information -Message "Routing and Remote Access Services server name is: $RRASName"
$RefVHDX = $config.REFVHDX
Write-LogEntry -Type Information -Message "Path to Reference VHDX is: $RefVHDX"
$domainnetbios = $envconfig.DomainNetBiosName
Write-LogEntry -Type Information -Message "WINNT domain name is: $domainnetbios"
$cmsitecode = $envConfig.CMSiteCode
Write-LogEntry -Type Information -Message "SCCM Site code is: $cmsitecode"
$SCCMDLPreDown = $config.SCCMDLPreDown
Write-LogEntry -Type Information -Message "SCCM Content was Predownloaded: $($sccmdlpredown -eq 1)"
$vmsnapshot = if ($config.Enablesnapshot -eq 1) {$true}else {$false} 
Write-LogEntry -Type Information -Message "Snapshots have been: $vmsnapshot"
$unattendpath = $config.REFVHDX -replace ($config.REFVHDX.split('\') | Select-Object -last 1), "Unattended.xml"
Write-LogEntry -Type Information -Message "Windows 2016 unattend file is: $unattendpath"
$servertemplates = (Get-Content "$scriptpath\SVRTemplates.json" -Raw | ConvertFrom-Json).ServerTemplates
#endregion 
    
    
#region create VMs
new-ENV -domuser $domuser -vmpath $vmpath -RefVHDX $RefVHDX -config $config -swname $swname -dftpwd $admpwd
new-RRASServer -vmpath $vmpath -RRASname $RRASname -RefVHDX $RefVHDX -localadmin $localadmin -swname $swname -ipsub $ipsub -vmSnapshotenabled:$vmsnapshot
new-DC -vmpath $vmpath -envconfig $envConfig -localadmin $localadmin -swname $swname -ipsub $ipsub -DomainFQDN $DomainFQDN -admpwd $admpwd -domuser $domuser -vmSnapshotenabled:$vmsnapshot
new-SCCMServer -envconfig $envConfig -vmpath $vmpath -localadmin $localadmin -ipsub $ipsub -DomainFQDN $DomainFQDN -domuser $domuser -config $config -admpwd $admpwd -domainnetbios $domainnetbios -cmsitecode $cmsitecode -SCCMDLPreDown $SCCMDLPreDown -vmSnapshotenabled:$vmsnapshot
new-CAServer -envconfig $envConfig -vmpath $vmpath -localadmin $localadmin -ipsub $ipsub -DomainFQDN $DomainFQDN -domuser $domuser -config $config -admpwd $admpwd -domainnetbios $domainnetbios -vmSnapshotenabled:$vmsnapshot
#endregion