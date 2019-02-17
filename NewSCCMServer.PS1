function new-SCCMServer {
    param(
        [Parameter(ParameterSetName = 'CMClass')]
        [CM]
        $CMConfig,
        [Parameter(ParameterSetName = 'NoClass')]
        [psobject]
        $envconfig,
        [Parameter(ParameterSetName = 'NoClass')]
        [string]
        $VHDXpath,
        [Parameter(ParameterSetName = 'NoClass')]
        [pscredential]
        $localadmin,
        [Parameter(ParameterSetName = 'NoClass')]
        [string]
        $IPAddress,
        [Parameter(ParameterSetName = 'NoClass')]
        [string]
        $DomainFQDN,
        [Parameter(ParameterSetName = 'NoClass')]
        [pscredential]
        $DomainUser,
        [Parameter(ParameterSetName = 'NoClass')]
        [psobject]
        $config,
        [Parameter(ParameterSetName = 'NoClass')]
        [string]
        $admpwd,
        [Parameter(ParameterSetName = 'NoClass')]
        [string]
        $domainnetbios,
        [Parameter(ParameterSetName = 'NoClass')]
        [string]
        $cmsitecode,
        [Parameter(ParameterSetName = 'NoClass')]
        [string]
        $SCCMDLPreDownloaded,
        [parameter(ParameterSetName = 'NoClass', Mandatory = $false)]
        [switch]
        $vmSnapshotenabled,
        [parameter(ParameterSetName = 'NoClass', Mandatory = $false)]
        [switch]
        $CAS,
        [Parameter(ParameterSetName = 'NoClass')]
        [switch]
        $PRI,
        [Parameter(ParameterSetName = 'NoClass')]
        [string]
        $casservername,
        [Parameter(ParameterSetName = 'NoClass')]
        [int]
        $cores,
        [Parameter(ParameterSetName = 'NoClass')]
        [int]
        $ram,
        [Parameter(ParameterSetName = 'NoClass')]
        [string]
        $name,
        [Parameter(ParameterSetName = 'NoClass')]
        [string]
        $DCIP,
        [Parameter(ParameterSetName = 'NoClass')]
        [string]
        $RefVHDX,
        [Parameter(ParameterSetName = 'NoClass')]
        [string]
        $SQLISO,
        [Parameter(ParameterSetName = 'NoClass')]
        [string]
        $SCCMPath,
        [Parameter(ParameterSetName = 'NoClass')]
        [string]
        $ADKPath,
        [Parameter(ParameterSetName = 'NoClass')]
        [ValidateSet("CAS","PRI","CASPRI")]
        [string]
        $CMServerType = "PRI",
        [Parameter(ParameterSetName = 'NoClass')]
        [string]
        $CASIPAddress
    )
    if (!$PSBoundParameters.ContainsKey('CMConfig')) {
        $CMConfig = [CM]::new()
        $CMConfig.AdmPwd = $admpwd
        $CMConfig.cmsitecode = $cmsitecode
        $CMConfig.cores = $Cores
        $CMConfig.ram = $ram
        $CMConfig.domainFQDN = $DomainFQDN
        $CMConfig.domainuser = $DomainUser
        $CMConfig.IPAddress = $IPAddress
        $CMConfig.DCIP = $DCIP
        $CMConfig.localadmin = $localadmin
        $CMConfig.network = $network
        $CMConfig.VHDXpath = $VHDXpath
        $CMConfig.VMSnapshotenabled = $vmSnapshotenabled.IsPresent
        $CMConfig.SCCMDLPreDownloaded = $SCCMDLPreDownloaded
        $CMConfig.name = $name
        $CMConfig.RefVHDX = $RefVHDX
        $CMConfig.SQLISO = $SQLISO
        $CMConfig.SCCMPath = $SCCMPath
        $CMConfig.ADKPath = $ADKPath
        $CMConfig.domainnetbios = $domainnetbios
        $CMConfig.CMServerType = $CMServerType
        $CMConfig.CASIPAddress = $CASIPAddress
    }
    $ipsubnet = $CMConfig.IPAddress.substring(0, ($CMConfig.IPAddress.length - ([ipaddress] $CMConfig.IPAddress).GetAddressBytes()[3].count - 1))
    Write-logentry -message "CM Server Started: $(Get-Date)" -type information
    #if ($cas.ispresent) {
    #    $cmname = "$($envconfig.env)`CMCAS"
    #}
    #else {
    #    $cmname = "$($envconfig.env)`CM"
    #}
    write-logentry -message "VM for CM will be named: $($CMConfig.name)" -type information
    Write-LogEntry -Message "CM Settings are: $($CMConfig | ConvertTo-Json)" -Type Information
    write-logentry -message "Path for the VHDX for $($CMConfig.name) is: $($CMConfig.VHDXpath)" -type information
    if (((Invoke-Pester -tag $cmConfig.CMServerType -PassThru -show None).TestResult | Where-Object {$_.name -match "CM Should Exist"}).result -notmatch "Passed") {
        write-logentry -message "CM for env:$($envconfig.env) doesn't exist, creating now" -type information
        if (((Invoke-Pester -tag $cmConfig.CMServerType -PassThru -show None).TestResult | Where-Object {$_.name -match "CM VHDX Should Exist"}).Result -match "Passed") {
            write-logentry -message "CM VHDX Already exists at path: $($CMConfig.VHDXpath) Please clean up and ReRun" -type error
            throw "CM VHDX Already Exists at path: $($CMConfig.VHDXpath) Please clean up and Rerun."
        }
        else {
            Copy-Item -Path $cmconfig.RefVHDX -Destination $CMConfig.VHDXpath
            write-logentry -message "Reference VHDX: $($CMConfig.refvhdx) has been copied to: $($CMConfig.VHDXpath)" -type information
            $disk = (mount-vhd -Path $CMConfig.VHDXpath -Passthru | Get-disk | Get-Partition | Where-Object {$_.type -eq 'Basic'}).DriveLetter
            write-logentry -message "$($CMConfig.VHDXpath) has been mounted to allow for file copy to $disk" -type information
            Copy-Item -Path $cmconfig.SCCMPath -Destination "$disk`:\data\SCCM" -Recurse
            write-logentry -message "SCCM Media copied to $disk`:\data\SCCM" -type information
            Copy-Item -Path $cmconfig.ADKPath -Destination "$disk`:\data\adk" -Recurse
            write-logentry -message "ADK Media copied to $disk`:\data\adk" -type information
            Dismount-VHD $CMConfig.VHDXpath
            write-logentry -message "$disk has been dismounted" -type information
        }
        if (((Invoke-Pester -tag $cmConfig.CMServerType -PassThru -show None).TestResult | Where-Object {$_.name -match "CM VHDX Should exist"}).Result -notmatch "Passed") {
            write-logentry -message "Error creating VHDX for CM. BUILD STOPPED" -type error
            throw "Error Creating the VHDX for CM"
        }
        else {
            write-logentry -message "Starting to create $($CMConfig.name)" -type information
            new-vm -name $CMConfig.name -MemoryStartupBytes ($cmconfig.ram * 1gb) -VHDPath $CMConfig.VHDXpath -Generation 2 | Set-VMMemory -DynamicMemoryEnabled:$false 
            write-logentry -message "Setting vCPU for $($CMConfig.name) to 4" -type information
            get-vm -name $CMConfig.name | Set-VMProcessor -Count $CMConfig.cores
            if (!($cmconfig.vmSnapshotenabled)) {
                set-vm -name $CMConfig.name -checkpointtype Disabled
            }
            write-logentry -message "$($CMConfig.name) has been created" -type information
            start-vm -Name $CMConfig.name
            write-logentry -message "CM Server named $($CMConfig.name) has been started" -type information
            Get-VMNetworkAdapter -VMName $CMConfig.name | Connect-VMNetworkAdapter -SwitchName $cmconfig.network
            write-logentry -message "vSwitch $($cmconfig.network) has been attached to $($CMConfig.name)" -type information
        }
        while ((Invoke-Command -VMName $CMConfig.name -Credential $CMConfig.localadmin {"Test"} -ErrorAction SilentlyContinue) -ne "Test") {Start-Sleep -Seconds 5}
        $cmsessionLA = New-PSSession -vmname $CMConfig.name -credential $CMConfig.localadmin
        if ($null -eq $cmsessionLA) {throw "Issue with CM Local User Account"}
        write-logentry -message "PowerShell Direct session for $($CMConfig.localadmin.username) has been initated with CM server named: $($CMConfig.name)" -type information
        $cmnics = Invoke-Command -session $cmsessionLA -ScriptBlock {Get-NetAdapter}
        write-logentry -message "The following network adaptors $($cmnics -join ",") have been found on: $($CMConfig.name)" -type information
        if (((Invoke-Pester -tag $cmConfig.CMServerType -PassThru -show None).TestResult | Where-Object {$_.name -match "CM IP Address"}).result -notmatch "Passed") {
            $IPGateway = "$ipsubnet`1"
            $null = Invoke-Command -session $cmsessionLA -ScriptBlock {param($t, $i, $g, $d) new-NetIPAddress -InterfaceIndex $t -AddressFamily IPv4 -IPAddress "$i" -PrefixLength 24 -DefaultGateway "$g"; Set-DnsClientServerAddress -ServerAddresses ($d) -InterfaceIndex $t} -ArgumentList $cmnics.InterfaceIndex, $CMConfig.IPAddress, $IPGateway, $CMConfig.DCIP
            write-logentry -message "IP Address $($CMConfig.IPAddress) has been assigned to $($CMConfig.name)" -type information
            start-sleep 300
        }
        if (((Invoke-Pester -tag $cmConfig.CMServerType -PassThru -show None).TestResult | Where-Object {$_.name -match "CM has access to $($CMConfig.DomainFQDN)"}).result -match "Passed") {
            while ((Invoke-Command -VMName $CMConfig.name -Credential $CMConfig.localadmin {param($i)(test-netconnection "$i" -ErrorAction SilentlyContinue).pingsucceeded} -ArgumentList $cmconfig.DCIP -ErrorAction SilentlyContinue) -ne $true -and $stop -ne (get-date)) {Start-Sleep -Seconds 5}
            Invoke-Command -session $cmsessionLA -ErrorAction SilentlyContinue -ScriptBlock {param($env, $domuser) Clear-DnsClientCache; Add-Computer -DomainName $env -domainCredential $domuser -Restart; Start-Sleep -Seconds 15; Restart-Computer -Force -Delay 0} -ArgumentList $cmconfig.domainFQDN, $CMConfig.domainuser
            write-logentry -message "Joined $($CMConfig.name) to domain $($cmconfig.domainFQDN)" -type information
            $stop = (get-date).AddMinutes(5)
            while ((Invoke-Command -VMName $CMConfig.name -Credential $CMConfig.domainuser {"Test"} -ErrorAction SilentlyContinue) -ne "Test" -and $stop -ne (get-date)) {Start-Sleep -Seconds 5}
        }
        else {
            write-logentry -message "Couldn't find $($cmconfig.domainFQDN)" -type error
            throw "CM Server can't resolve $($cmconfig.domainFQDN)"
        }
        $cmsession = New-PSSession -VMName $CMConfig.name -Credential $CMConfig.domainuser
        write-logentry -message "PowerShell Direct session for $($CMConfig.domainuser.username) has been initated with CM Server named: $($CMConfig.name)" -type information
        if ($null -eq $cmsession) {throw "Issue with CM Domain User Account"}
        if (((Invoke-Pester -tag $cmConfig.CMServerType -PassThru -show None).TestResult | Where-Object {$_.name -match "CM .Net Feature installed"}).result -notmatch "Passed") {
            Invoke-Command -session $cmsession -ScriptBlock {Add-WindowsFeature -Name NET-Framework-Features, NET-Framework-Core -Source "C:\data"} | Out-Null
            write-logentry -message ".Net 3.5 enabled on $($CMConfig.name)" -type information
        }
        if (((Invoke-Pester -tag $cmConfig.CMServerType -PassThru -show None).TestResult | Where-Object {$_.name -match "CM Features are installed"}).result -notmatch "Passed") {
            Invoke-Command -session $cmsession -ScriptBlock {Add-WindowsFeature BITS, BITS-IIS-Ext, BITS-Compact-Server, Web-Server, Web-WebServer, Web-Common-Http, Web-Default-Doc, Web-Dir-Browsing, Web-Http-Errors, Web-Static-Content, Web-Http-Redirect, Web-App-Dev, Web-Net-Ext, Web-Net-Ext45, Web-ASP, Web-Asp-Net, Web-Asp-Net45, Web-CGI, Web-ISAPI-Ext, Web-ISAPI-Filter, Web-Health, Web-Http-Logging, Web-Custom-Logging, Web-Log-Libraries, Web-Request-Monitor, Web-Http-Tracing, Web-Performance, Web-Stat-Compression, Web-Security, Web-Filtering, Web-Basic-Auth, Web-IP-Security, Web-Url-Auth, Web-Windows-Auth, Web-Mgmt-Tools, Web-Mgmt-Console, Web-Mgmt-Compat, Web-Metabase, Web-Lgcy-Mgmt-Console, Web-Lgcy-Scripting, Web-WMI, Web-Scripting-Tools, Web-Mgmt-Service, RDC, RSAT-AD-PowerShell} | Out-Null
            write-logentry -message "Windows Features enabled on $($CMConfig.name)" -type information
        }
        if (((Invoke-Pester -tag $cmConfig.CMServerType -PassThru -show None).TestResult | Where-Object {$_.name -match "CM SQL Instance is installed"}).result -notmatch "Passed") {
            write-logentry -message "Start SQL Install on $($CMConfig.name)" -type information
            new-CMSQLInstance -cmname $CMConfig.name -cmsession $cmsession -SQLISO $CMConfig.SQLISO -domainnetbios $CMConfig.domainnetbios -admpwd $cmconfig.admpwd
        }
        if (((Invoke-Pester -tag $cmConfig.CMServerType -PassThru -show None).TestResult | Where-Object {$_.name -match "CM ADK installed"}).result -notmatch "Passed") {
            write-logentry -message "ADK is installing on $($CMConfig.name)" -type information
            Invoke-Command -Session $cmsession -ScriptBlock {Start-Process -FilePath "c:\data\adk\adksetup.exe" -Wait -ArgumentList " /Features OptionId.DeploymentTools OptionId.WindowsPreinstallationEnvironment OptionId.ImagingAndConfigurationDesigner OptionId.UserStateMigrationTool /norestart /quiet /ceip off"}
            write-logentry -message "ADK is installed on $($CMConfig.name)" -type information
        }
        if($CMConfig.CMServerType -eq "CAS")
        {
            invoke-command -Session $cmsession -ScriptBlock {new-netfirewallrule -DisplayName "CAS Inbound" -Action Allow -Profile Any -Enabled true -Direction Inbound -Protocol TCP -LocalPort 1433,4022}
        }
        if (((Invoke-Pester -tag $cmConfig.CMServerType -PassThru -show None).TestResult | Where-Object {$_.name -match "CM SCCM Installed"}).result -notmatch "Passed") {
            if($CMConfig.CMServerType -eq "CASPRI")
            {
                new-CMInstance -CMServerType $CMConfig.CMServerType -cmsession $cmsession -cmname $CMConfig.name -cmsitecode $cmconfig.cmsitecode -domainfqdn $CMConfig.domainFQDN -ver "Prod" -ipsub $ipsubnet -domainnetbios $CMConfig.domainnetbios -CASIPAddress $CMConfig.CASIPAddress
            }
            else {
                new-CMInstance -CMServerType $CMConfig.CMServerType -cmsession $cmsession -cmname $CMConfig.name -cmsitecode $cmconfig.cmsitecode -domainfqdn $CMConfig.domainFQDN -ver "Prod" -ipsub $ipsubnet -domainnetbios $CMConfig.domainnetbios #-cas:($cas.IsPresent) -pri:($pri.ispresent) -casservername $casservername    
            }
            
        }
        $cmsession | remove-PSSession
        write-logentry -message "Powershell Direct session for $($CMConfig.domainuser.username) on $($CMConfig.name) has been disposed" -type information
    }
    $CMConfig.Built = $true
    $CMConfig.save("$vmpath\$($config.Name)`config.json")
    Invoke-Pester -tag $cmConfig.CMServerType
    Write-Output "CM Server Completed: $(Get-Date)"
    write-logentry -message "SCCM Server installation has completed on $($CMConfig.name)" -type information
}
