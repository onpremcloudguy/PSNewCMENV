function new-SCCMServer {
    param(
        [Parameter(Mandatory)]
        [psobject]
        $envconfig,
        [Parameter(Mandatory)]
        [string]
        $vmpath,
        [Parameter(Mandatory)]
        [pscredential]
        $localadmin,
        [Parameter(Mandatory)]
        [string]
        $ipsub,
        [Parameter(Mandatory)]
        [string]
        $DomainFQDN,
        [Parameter(Mandatory)]
        [pscredential]
        $domuser,
        [Parameter(Mandatory)]
        [psobject]
        $config,
        [Parameter(Mandatory)]
        [string]
        $admpwd,
        [Parameter(Mandatory)]
        [string]
        $domainnetbios,
        [Parameter(Mandatory)]
        [string]
        $cmsitecode,
        [Parameter(Mandatory)]
        [string]
        $SCCMDLPreDown,
        [parameter(Mandatory = $false)]
        [switch]
        $vmSnapshotenabled,
        [Parameter(Mandatory = $false)]
        [switch]
        $CAS,
        [parameter]
        [switch]
        $PRI,
        [parameter]
        [string]
        $casservername
    )
    Write-logentry -message "CM Server Started: $(Get-Date)" -type information
    if ($cas.ispresent) {
        $cmname = "$($envconfig.env)`CMCAS"
    }
    else {
        $cmname = "$($envconfig.env)`CM"
    }
    
    $cmvhdx = "$vmpath\$($cmname)c.vhdx"
    write-logentry -message "VM for CM will be named: $cmname" -type information
    write-logentry -message "Path for the VHDX for $cmname is: $cmvhdx" -type information
    if (((Invoke-Pester -TestName "CM" -PassThru -show None).TestResult | Where-Object {$_.name -match "CM Should Exist"}).result -notmatch "Passed") {
        write-logentry -message "CM for env:$($envconfig.env) doesn't exist, creating now" -type information
        if (((Invoke-Pester -TestName "CM" -PassThru -show None).TestResult | Where-Object {$_.name -match "CM VHDX Should Exist"}).Result -match "Passed") {
            write-logentry -message "CM VHDX Already exists at path: $cmvhdx Please clean up and ReRun" -type error
            throw "CM VHDX Already Exists at path: $CMVHDX Please clean up and Rerun."
        }
        else {
            Copy-Item -Path $RefVHDX -Destination $CMVHDX
            write-logentry -message "Reference VHDX: $refvhdx has been copied to: $cmvhdx" -type information
            $disk = (mount-vhd -Path $cmvhdx -Passthru | Get-disk | Get-Partition | Where-Object {$_.type -eq 'Basic'}).DriveLetter
            write-logentry -message "$cmvhdx has been mounted to allow for file copy to $disk" -type information
            Copy-Item -Path $config.SCCMPath -Destination "$disk`:\data\SCCM" -Recurse
            write-logentry -message "SCCM Media copied to $disk`:\data\SCCM" -type information
            Copy-Item -Path $config.ADKPath -Destination "$disk`:\data\adk" -Recurse
            write-logentry -message "ADK Media copied to $disk`:\data\adk" -type information
            Dismount-VHD $cmvhdx
            write-logentry -message "$disk has been dismounted" -type information
        }
        if (((Invoke-Pester -TestName "CM" -PassThru -show None).TestResult | Where-Object {$_.name -match "CM VHDX Should exist"}).Result -notmatch "Passed") {
            write-logentry -message "Error creating VHDX for CM. BUILD STOPPED" -type error
            throw "Error Creating the VHDX for CM"
        }
        else {
            write-logentry -message "Starting to create $cmname" -type information
            new-vm -name $cmname -MemoryStartupBytes 12gb -VHDPath $cmvhdx -Generation 2 | Set-VMMemory -DynamicMemoryEnabled:$false 
            write-logentry -message "Setting vCPU for $cmname to 4" -type information
            get-vm -name $cmname | Set-VMProcessor -Count 4
            if ($vmSnapshotenabled.IsPresent) {
                set-vm -name $cmname -checkpointtype Disabled
            }
            write-logentry -message "$cmname has been created" -type information
            start-vm -Name $cmname
            write-logentry -message "CM Server named $cmname has been started" -type information
            Get-VMNetworkAdapter -VMName $cmname | Connect-VMNetworkAdapter -SwitchName $swname
            write-logentry -message "vSwitch $swname has been attached to $cmname" -type information
        }
        while ((Invoke-Command -VMName $cmname -Credential $localadmin {"Test"} -ErrorAction SilentlyContinue) -ne "Test") {Start-Sleep -Seconds 5}
        $cmsessionLA = New-PSSession -vmname $cmname -credential $localadmin
        if ($null -eq $cmsessionLA) {throw "Issue with CM Local User Account"}
        write-logentry -message "PowerShell Direct session for $($localadmin.username) has been initated with CM server named: $cmname" -type information
        $cmnics = Invoke-Command -session $cmsessionLA -ScriptBlock {Get-NetAdapter}
        write-logentry -message "The following network adaptors $($cmnics -join ",") have been found on: $cmname" -type information
        if (((Invoke-Pester -TestName "CM" -PassThru -show None).TestResult | Where-Object {$_.name -match "CM IP Address"}).result -notmatch "Passed") {
            $null = Invoke-Command -session $cmsessionLA -ScriptBlock {param($t, $i) new-NetIPAddress -InterfaceIndex $t -AddressFamily IPv4 -IPAddress "$i`15" -PrefixLength 24 -DefaultGateway "$i`1"; Set-DnsClientServerAddress -ServerAddresses ("$i`10") -InterfaceIndex $t} -ArgumentList $cmnics.InterfaceIndex, $ipsub
            write-logentry -message "IP Address $ipsub`11 has been assigned to $cmname" -type information
            start-sleep 300
        }
        if (((Invoke-Pester -TestName "CM" -PassThru -show None).TestResult | Where-Object {$_.name -match "CM has access to $DomainFQDN"}).result -match "Passed") {
            while ((Invoke-Command -VMName $cmname -Credential $cmsessionLA {param($i)(test-netconnection "$i.10").pingsucceeded} -ArgumentList $ipsub -ErrorAction SilentlyContinue) -ne $true -and $stop -ne (get-date)) {Start-Sleep -Seconds 5}
            Invoke-Command -session $cmsessionLA -ErrorAction SilentlyContinue -ScriptBlock {param($env, $domuser) Clear-DnsClientCache; Add-Computer -DomainName $env -domainCredential $domuser -Restart; Start-Sleep -Seconds 15; Restart-Computer -Force -Delay 0} -ArgumentList $DomainFQDN, $domuser
            write-logentry -message "Joined $cmname to domain $domainFQDN" -type information
            $stop = (get-date).AddMinutes(5)
            while ((Invoke-Command -VMName $cmname -Credential $domuser {"Test"} -ErrorAction SilentlyContinue) -ne "Test" -and $stop -ne (get-date)) {Start-Sleep -Seconds 5}
        }
        else {
            write-logentry -message "Couldn't find $domainFQDN" -type error
            throw "CM Server can't resolve $DomainFQDN"
        }
        $cmsession = New-PSSession -VMName $cmname -Credential $domuser
        write-logentry -message "PowerShell Direct session for $($domuser.username) has been initated with CM Server named: $cmname" -type information
        if ($null -eq $cmsession) {throw "Issue with CM Domain User Account"}
        if (((Invoke-Pester -TestName "CM" -PassThru -show None).TestResult | Where-Object {$_.name -match "CM .Net Feature installed"}).result -notmatch "Passed") {
            Invoke-Command -session $cmsession -ScriptBlock {Add-WindowsFeature -Name NET-Framework-Features, NET-Framework-Core -Source "C:\data"} | Out-Null
            write-logentry -message ".Net 3.5 enabled on $CMname" -type information
        }
        if (((Invoke-Pester -TestName "CM" -PassThru -show None).TestResult | Where-Object {$_.name -match "CM Features are installed"}).result -notmatch "Passed") {
            Invoke-Command -session $cmsession -ScriptBlock {Add-WindowsFeature BITS, BITS-IIS-Ext, BITS-Compact-Server, Web-Server, Web-WebServer, Web-Common-Http, Web-Default-Doc, Web-Dir-Browsing, Web-Http-Errors, Web-Static-Content, Web-Http-Redirect, Web-App-Dev, Web-Net-Ext, Web-Net-Ext45, Web-ASP, Web-Asp-Net, Web-Asp-Net45, Web-CGI, Web-ISAPI-Ext, Web-ISAPI-Filter, Web-Health, Web-Http-Logging, Web-Custom-Logging, Web-Log-Libraries, Web-Request-Monitor, Web-Http-Tracing, Web-Performance, Web-Stat-Compression, Web-Security, Web-Filtering, Web-Basic-Auth, Web-IP-Security, Web-Url-Auth, Web-Windows-Auth, Web-Mgmt-Tools, Web-Mgmt-Console, Web-Mgmt-Compat, Web-Metabase, Web-Lgcy-Mgmt-Console, Web-Lgcy-Scripting, Web-WMI, Web-Scripting-Tools, Web-Mgmt-Service, RDC, RSAT-AD-PowerShell} | Out-Null
            write-logentry -message "Windows Features enabled on $cmname" -type information
        }
        if (((Invoke-Pester -TestName "CM" -PassThru -show None).TestResult | Where-Object {$_.name -match "CM SQL Instance is installed"}).result -notmatch "Passed") {
            write-logentry -message "Start SQL Install on $cmname" -type information
            new-CMSQLInstance -cmname $cmname -cmsession $cmsession -config $config -domainnetbios $domainnetbios -admpwd $admpwd
        }
        if (((Invoke-Pester -TestName "CM" -PassThru -show None).TestResult | Where-Object {$_.name -match "CM ADK installed"}).result -notmatch "Passed") {
            write-logentry -message "ADK is installing on $cmname" -type information
            Invoke-Command -Session $cmsession -ScriptBlock {Start-Process -FilePath "c:\data\adk\adksetup.exe" -Wait -ArgumentList " /Features OptionId.DeploymentTools OptionId.WindowsPreinstallationEnvironment OptionId.ImagingAndConfigurationDesigner OptionId.UserStateMigrationTool /norestart /quiet /ceip off"}
            write-logentry -message "ADK is installed on $cmname" -type information
        }
        if (((Invoke-Pester -TestName "CM" -PassThru -show None).TestResult | Where-Object {$_.name -match "CM SCCM Installed"}).result -notmatch "Passed") {
            new-CMInstance -cmsession $cmsession -cmname $cmname -cmsitecode $cmsitecode -domainfqdn $domainFQDN -ver "Prod" -ipsub $ipsub -domainnetbios $domainnetbios #-cas:($cas.IsPresent) -pri:($pri.ispresent) -casservername $casservername
        }
        $cmsession | remove-PSSession
        write-logentry -message "Powershell Direct session for $($domuser.username) on $cmname has been disposed" -type information
    }

    Invoke-Pester -TestName "CM"
    Write-Output "CM Server Completed: $(Get-Date)"
    write-logentry -message "SCCM Server installation has completed on $cmname" -type information
}
