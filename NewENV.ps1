#region Functions
function new-ENV {
    param(
        [Parameter(Mandatory)]
        [pscredential]
        $domuser,
        [Parameter(Mandatory)]
        [string]
        $vmpath,
        [Parameter(Mandatory)]
        [string]
        $RefVHDX,
        [Parameter(Mandatory)]
        [psobject]
        $config,
        [Parameter(Mandatory)]
        [string]
        $swname,
        [Parameter(Mandatory)]
        [string]
        $dftpwd
    )
    if ($domuser -eq $null) {throw "Issue with the Dom User"}
    Write-LogEntry -Type Information -Message "Creating the base requirements for Lab Environment"
    $TREFVHDX = Invoke-Pester -TestName "Reference-VHDX" -PassThru -Show Passed
    if ($TREFVHDX.PassedCount -eq 1) {
        Write-LogEntry -Type Information -Message "Reference image already exists in: $refvhdx"
    }
    else {
        if (!(Test-Path $vmpath)) {New-Item -ItemType Directory -Force -Path $vmpath}
        else {
            if(!(Test-Path "$($scriptpath)\unattended.xml"))
            {
                New-UnattendXml -admpwd $dftpwd -outfile "$($scriptpath)\unattended.xml"
            }
            Write-LogEntry -Type Information -Message "Reference image doesn't exist, will create it now"
            new-LabVHDX -VHDXPath $RefVHDX -Unattend "$($scriptpath)\unattended.xml" -WinISO $config.WIN16ISO -WinNet35Cab $config.WINNET35CAB
            Write-LogEntry -Type Information -Message "Reference image has been created in: $refvhdx"
        }
    }
    $TNetwork = Invoke-Pester -TestName "vSwitch" -PassThru -Show None
    if (($TNetwork.TestResult | Where-Object {$_.name -eq 'Internet VSwitch should exist'}).result -eq 'Failed') {
        Write-LogEntry -Type Information -Message "vSwitch named Internet does not exist"
        $nic = Get-NetAdapter -Physical
        Write-LogEntry -Type Information -Message "Following physical network adaptors found: $($nic.Name -join ",")"
        if ($nic.count -gt 1) {
            Write-Verbose "Multiple Network Adptors found. "
            $i = 1
            $oOptions = @()
            $nic | ForEach-Object {
                $oOptions += [pscustomobject]@{
                    Item = $i
                    Name = $_.Name
                }
                $i++
            }
            $oOptions | Out-Host
            $selection = Read-Host -Prompt "Please make a selection"
            Write-LogEntry -Type Information -Message "The following physical network adaptor has been selected for Internet access: $selection"
            $Selected = $oOptions | Where-Object {$_.Item -eq $selection}
            New-VMSwitch -Name 'Internet' -NetAdapterName $selected.name -AllowManagementOS:$true | Out-Null
            Write-LogEntry -Type Information -Message "Internet vSwitch has been created."
        }
    }
    if (($TNetwork.TestResult | Where-Object {$_.name -eq 'Lab VMSwitch Should exist'}).result -eq 'Failed') {
        Write-LogEntry -Type Information -Message "Private vSwitch named $swname does not exist"
        New-VMSwitch -Name $swname -SwitchType Private | Out-Null
        Write-LogEntry -Type Information -Message "Private vSwitch named $swname has been created."
    }
    Write-LogEntry -Type Information -Message "Base requirements for Lab Environment has been met"
}

function new-LabVHDX {
    param
    (
    [parameter(Mandatory)]    
    [string]
    $vhdxpath,
    [parameter(Mandatory)]
    [string]
    $unattend,
    [parameter(Mandatory)]
    [switch]
    $core,
    [parameter(Mandatory)]
    [string]
    $WinISO,
    [parameter(Mandatory)]
    [String]
    $WinNet35Cab
    )
    $convmod = get-module -ListAvailable -Name 'Convert-WindowsImage'
    if ($convmod.count -ne 1) {
        Install-Module -name 'Convert-WindowsImage' -Scope AllUsers
    }
    else {
        Update-Module -Name 'Convert-WindowsImage'    
    }
    Import-module -name 'Convert-Windowsimage'
    $cornum = 2
    if ($core.IsPresent) {$cornum = 3}else {$cornum = 4}
    Convert-WindowsImage -SourcePath $WinISO -Edition $cornum -VhdType Dynamic -VhdFormat VHDX -VhdPath $vhdxpath -DiskLayout UEFI -SizeBytes 127gb -UnattendPath $unattend
    $drive = (Mount-VHD -Path $vhdxpath -Passthru | Get-Disk | Get-Partition | Where-Object {$_.type -eq 'Basic'}).DriveLetter
    new-item "$drive`:\data" -ItemType Directory | Out-Null
    Copy-Item -Path $WinNet35Cab -Destination "$drive`:\data\microsoft-windows-netfx3-ondemand-package.cab"
    Dismount-VHD -Path $vhdxpath
}

function New-UnattendXml{
    [CmdletBinding()]
    Param
    (
        # The password to have unattnd.xml set the local Administrator to
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [Alias('password')] 
        [string]
        $admpwd,
        [Parameter(Mandatory)]
        [string]
        $outfile
    )
$unattendTemplate = [xml]@" 
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <servicing>
        <package action="install" permanence="removable">
            <assemblyIdentity name="Microsoft-Windows-NetFx3-OnDemand-Package" version="10.0.14393.0" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" />
            <source location="c:\data\microsoft-windows-netfx3-ondemand-package.cab" />
        </package>
    </servicing>
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <UserAccounts>
                <AdministratorPassword>
                    <Value><<ADM_PWD>></Value> 
                    <PlainText>True</PlainText> 
                </AdministratorPassword>
            </UserAccounts>
            <OOBE>
                <VMModeOptimizations>
                    <SkipNotifyUILanguageChange>true</SkipNotifyUILanguageChange>
                    <SkipWinREInitialization>true</SkipWinREInitialization>
                </VMModeOptimizations>
                <SkipMachineOOBE>true</SkipMachineOOBE>
                <HideEULAPage>true</HideEULAPage>
                <HideLocalAccountScreen>true</HideLocalAccountScreen>
                <ProtectYourPC>3</ProtectYourPC>
                <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
                <NetworkLocation>Work</NetworkLocation>
                <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
            </OOBE>
        </component>
        <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <InputLocale>en-au</InputLocale>
            <SystemLocale>en-us</SystemLocale>
            <UILanguage>en-au</UILanguage>
            <UILanguageFallback>en-us</UILanguageFallback>
            <UserLocale>en-au</UserLocale>
        </component>
    </settings>
</unattend>
"@
$unattendTemplate -replace "<<ADM_PWD>>", $admpwd | Out-File -FilePath $outfile -Encoding utf8
}

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
foreach($psfile in get-childitem -Filter *.ps1 | Where-Object {$_.name -notin ("newenv.ps1","NewENV.Tests.ps1")})
{
    . ".\$psfile"
}


#region import JSON Settings
$scriptpath = $PSScriptRoot
$config = Get-Content "$scriptpath\env.json" -Raw | ConvertFrom-Json
$envConfig = $config.ENVConfig | Where-Object {$_.env -eq $config.env}
$script:logfile = "$($envConfig.vmpath)\Build.log"
if(!(Test-Path $envConfig.vmpath)) {new-item -ItemType Directory -Force -Path $envConfig.vmpath | Out-Null}
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
$vmsnapshot = if($config.Enablesnapshot -eq 1){$true}else{$false} 
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