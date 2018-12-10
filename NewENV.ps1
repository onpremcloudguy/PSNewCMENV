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

function new-RRASServer {
    param(
        [Parameter(Mandatory)]
        [string]
        $vmpath,
        [Parameter(Mandatory)]
        [string]
        $RRASname,
        [Parameter(Mandatory)]
        [string]
        $RefVHDX,
        [Parameter(Mandatory)]
        [pscredential]
        $localadmin,
        [Parameter(Mandatory)]
        [string]
        $swname,
        [Parameter(Mandatory)]
        [string]
        $ipsub,
        [parameter(Mandatory=$false)]
        [switch]
        $vmSnapshotenabled
    )
    Write-LogEntry -Message "RRAS Server started $(Get-Date)" -type Information
    if (((Invoke-Pester -TestName "RRAS" -PassThru -show None).TestResult | Where-Object {$_.name -match "RRAS Server Should exist"}).Result -notmatch "Passed") {
        $RRASvhdx = "$(split-path $vmpath)\$($RRASname)c.vhdx"
        Write-LogEntry -Type Information -Message "Path for the VHDX for RRAS is: $RRASVHDX"
        if (((Invoke-Pester -TestName "RRAS" -PassThru -show None).TestResult | Where-Object {$_.name -match "VHDX Should exist"}).Result -match "Passed") {
            Write-LogEntry -Type Error -Message "RRAS VHDX Already Exists at path: $RRASVHDX Please clean up and Rerun. Build STOPPED" 
            throw "RRAS VHDX Already Exists at path: $RRASVHDX Please clean up and Rerun."
        }
        else {
            Copy-Item -Path $RefVHDX -Destination $RRASvhdx
            Write-LogEntry -Type Information -Message "Reference VHDX: $refvhdx has been copied to: $rrasvhdx"
        }
        if (((Invoke-Pester -TestName "RRAS" -PassThru -show None).TestResult | Where-Object {$_.name -match "VHDX Should exist"}).Result -notmatch "Passed") {
            Write-LogEntry -Type Error -Message "Error Creating the VHDX for RRAS. Build STOPPED"
            throw "Error Creating the VHDX for RRAS"
        }
        else {
            Write-LogEntry -Type Information -Message "Starting to create RRAS Server"
            new-vm -Name $RRASname -MemoryStartupBytes 8Gb -VHDPath $rrasvhdx -Generation 2 | out-null # | Set-VMMemory -DynamicMemoryEnabled:$false
            Enable-VMIntegrationService -VMName $RRASname -Name "Guest Service Interface"
            if($vmSnapshotenabled.IsPresent){
                set-vm -Name $RRASname -CheckpointType Disabled
            }
            Write-LogEntry -Type Information -Message "RRAS Server has been created"
            if (((Invoke-Pester -TestName "RRAS" -PassThru -show None).TestResult | Where-Object {$_.name -match "RRAS Server Should exist"}).Result -notmatch "Passed") {Write-LogEntry -Type Error -message "Error Creating the VHDX for RRAS"; throw "Error Creating the VHDX for RRAS"}
        }
        start-vm -Name $RRASname
        Write-LogEntry -Type Information -Message "RRAS Server named $RRASName has been started"
        Get-VMNetworkAdapter -vmname $RRASname | Connect-VMNetworkAdapter -SwitchName 'Internet' | Set-VMNetworkAdapter -Name 'Internet' -DeviceNaming On
        Write-LogEntry -Type Information -Message "vSwitch named Internet has been connected to the RRAS Server"
        while ((Invoke-Command -VMName $RRASname -Credential $localadmin {"Test"} -ErrorAction SilentlyContinue) -ne "Test") {Start-Sleep -Seconds 5}
        $rrasSession = New-PSSession -VMName $RRASname -Credential $localadmin
        Write-LogEntry -Type Information -Message "PowerShell Direct session for $($localadmin.UserName) has been initated with RRAS Server named: $RRASname"
        if (((Invoke-Pester -TestName "RRAS" -PassThru -show None).TestResult | Where-Object {$_.name -match "RRAS Routing Installed"}).Result -match "Passed") {
            Write-Verbose "RRAS Routing Already installed"
        }
        else {
            $null = Invoke-Command -Session $rrasSession -ScriptBlock {Install-WindowsFeature Routing -IncludeManagementTools}
            Write-LogEntry -Type Information -Message "Routing and Remove Access services role now installed on: $RRASname"
            if (((Invoke-Pester -TestName "RRAS" -PassThru -show None).TestResult | Where-Object {$_.name -match "RRAS Routing Installed"}).Result -notmatch "Passed") {Write-LogEntry -Type Error -Message "Error installing RRAS Routing, Build STOPPED";throw "Error installing RRAS Routing"}
        }
        while ((Invoke-Command -VMName $RRASname -Credential $localadmin {"Test"} -ErrorAction SilentlyContinue) -ne "Test") {Start-Sleep -Seconds 5}
        $rrasSession = New-PSSession -VMName $RRASname -Credential $localadmin
        Write-LogEntry -Type Information -Message "PowerShell Direct session for $($localadmin.UserName) has been initated with RRAS Server named: $RRASname"
        if (((Invoke-Pester -TestName "RRAS" -PassThru -show None).TestResult | Where-Object {$_.name -match "RRAS External NIC Renamed"}).Result -match "Passed") {
            Write-Verbose "RRAS NIC Already Named external"
        }
        else {
            Invoke-Command -Session $rrasSession -ScriptBlock {Get-NetAdapter -Physical -name Ethernet | rename-netadapter -newname "External" }
            Write-LogEntry -Type Information -Message "Renamed Network Adaptor to 'External'"
            if (((Invoke-Pester -TestName "RRAS" -PassThru -show None).TestResult | Where-Object {$_.name -match "RRAS External NIC Renamed"}).Result -notmatch "Passed") {write-logentry -Type Error -Message "RRAS NIC not renamed. Build STOPPED";throw "RRAS NIC not renamed"}
        }
        Invoke-Command -Session $rrasSession -ScriptBlock {Install-RemoteAccess -VpnType Vpn; netsh routing ip nat install; netsh routing ip nat add interface "External"; netsh routing ip nat set interface "External" mode=full}
        Write-LogEntry -Type Information -Message "Routing configured for External Network adapter"
        $rrasSession | Remove-PSSession
        Write-LogEntry -Type Information -Message "PowerShell Direct Session for $rrasname has been disconnected"
    }
    else {
        Start-VM $RRASname
        Write-LogEntry -Type Information -Message "Starting Routing and Remote Access Services server named: $RRASName"
        while ((Invoke-Command -VMName $RRASname -Credential $localadmin {"Test"} -ErrorAction SilentlyContinue) -ne "Test") {Start-Sleep -Seconds 5}
    }

    if ((Get-VMNetworkAdapter -VMName $RRASname | Where-Object {$_.switchname -eq $swname}).count -eq 0) {
        if (((Invoke-Pester -TestName "RRAS" -PassThru -show None).TestResult | Where-Object {$_.name -match "RRAS Lab IP Address Set"}).Result -match "Passed") {
            Write-Verbose "RRAS NIC Already Named $swname"
        }
        else {
            $rrasSession = New-PSSession -VMName $RRASname -Credential $localadmin
            Write-LogEntry -Type Information -Message "PowerShell Direct session for $($localadmin.UserName) has been initated with RRAS Server named: $RRASname"
            $rrasnics = Invoke-Command -Session $rrasSession -ScriptBlock {Get-NetAdapter}
            Write-LogEntry -Type Information -Message "The following Network Adaptors $($rrasnics -join ",") have been found on: $rrasname"
            get-vm -Name $RRASname | Add-VMNetworkAdapter -SwitchName $swname
            Write-LogEntry -Type Information -Message "Network adaptor for switch: $SWName has been added to: $RRASName"
            Start-Sleep -Seconds 10
            $rrasnewnics = Invoke-Command -Session $rrasSession -ScriptBlock {Get-NetAdapter}
            Write-LogEntry -Type Information -Message "The following Network Adaptors $($rrasnewnics -join ",") have been found on: $rrasname"
            $t = Compare-Object -ReferenceObject $rrasnics -DifferenceObject $rrasnewnics -PassThru
            $null = Invoke-Command -Session $rrasSession -ScriptBlock {param($t, $i) new-NetIPAddress -InterfaceIndex $t -AddressFamily IPv4 -IPAddress "$i`1" -PrefixLength 24} -ArgumentList $t.InterfaceIndex, $ipsub
            Write-LogEntry -Type Information -Message "Ip address of $ipsubnet`.1 has been set on Network Adaptor $swname for VM $RRASName"
            Invoke-Command -Session $rrasSession -ScriptBlock {param($n, $t)Get-NetAdapter -InterfaceIndex $n | rename-netadapter -newname $t } -ArgumentList $t.InterfaceIndex, $swname
            Invoke-Command -Session $rrasSession -ScriptBlock {param($n)get-service -name "remoteaccess" | Restart-Service -WarningAction SilentlyContinue; netsh routing ip nat add interface $n} -ArgumentList $swname
            Write-LogEntry -Type Information -Message "Network adaptor renamed to: $SWname and Routing configured."
            if (((Invoke-Pester -TestName "RRAS" -PassThru -show None).TestResult | Where-Object {$_.name -match "RRAS Lab IP Address Set"}).Result -notmatch "Passed") {Write-LogEntry -Type Error -Message "Lab IP address not added. Build STOPPED";throw "Lab IP address not added"}
        }
        $rrasSession | Remove-PSSession
        Write-LogEntry -Type Information -Message "PowerShell Direct Session for $rrasname has been disconnected"
    }
    write-logentry -Type Information -Message "RRAS Server Completed: $(Get-Date)"
    invoke-pester -name "RRAS"
}

function new-DC {
    param(
        [Parameter(Mandatory)]
        [string]
        $vmpath,
        [Parameter(Mandatory)]
        [psobject]
        $envconfig,
        [Parameter(Mandatory)]
        [pscredential]
        $localadmin,
        [Parameter(Mandatory)]
        [string]
        $swname,
        [Parameter(Mandatory)]
        [string]
        $ipsub,
        [Parameter(Mandatory)]
        [string]
        $DomainFQDN,
        [Parameter(Mandatory)]
        [string]
        $admpwd,
        [Parameter(Mandatory)]
        [pscredential]
        $domuser,
        [parameter(Mandatory=$false)]
        [switch]
        $vmSnapshotenabled
    )
    Write-LogEntry -Message "DC Server Started: $(Get-Date)" -Type Information
    $dcname = "$($envconfig.env)`DC"
    $dcvhdx = "$vmpath\$($dcname)c.vhdx"
    Write-LogEntry -Message "VM for DC will be named: $dcname" -type Information
    Write-LogEntry -Message "Path for the VHDX for $dcname is: $dcvhdx" -type information
    if (!((Invoke-Pester -TestName "DC" -PassThru -show None).TestResult | Where-Object {$_.name -match "DC Should Exist"}).result -notmatch "Passed") {
        write-logentry -message "DC for env: $($envconfig.env) doesn't exist, creating now" -Type Information
        if (((Invoke-Pester -TestName "DC" -PassThru -show None).TestResult | Where-Object {$_.name -match "DC VHDX Should Exist"}).Result -match "Passed") {
            Write-LogEntry -Message "DC VHDX Already Exists at path: $dcvhdx Please clean up and Rerun." -Type Error
            throw "DC VHDX Already Exists at path: $dcvhdx Please clean up and Rerun."
        }
        else {
            Copy-Item -Path $RefVHDX -Destination $dcvhdx
            Write-LogEntry -Message "Reference VHDX: $refvhdx has been copied to: $dcvhdx" -Type Information
        }
        if (((Invoke-Pester -TestName "DC" -PassThru -show None).TestResult | Where-Object {$_.name -match "DC VHDX Should exist"}).Result -notmatch "Passed") {
            Write-LogEntry -Message "Error Creating the VHDX for $dcname. Build STOPPED" -Type Error 
            throw "Error Creating the VHDX for DC"
        }
        else {
            Write-LogEntry -Message "Starting to create $dcname server" -Type Information
            new-vm -Name $dcname -MemoryStartupBytes 8Gb -VHDPath $dcvhdx -Generation 2
            Enable-VMIntegrationService -VMName $dcname -Name "Guest Service Interface"
            if($vmSnapshotenabled.IsPresent){
                set-vm -name $dcname -checkpointtype Disabled
            }
            Write-LogEntry -Message "$DCname has been created" -Type Information
            start-vm -Name $dcname
            Write-LogEntry -Message "DC server named $dcname has been started"
        }
        Get-VMNetworkAdapter -vmname $dcname | Connect-VMNetworkAdapter -SwitchName $swname
        Write-LogEntry -Message "vSwitch $swname has been attached to $dcname" -Type Information
        while ((Invoke-Command -VMName $dcname -Credential $localadmin {"Test"} -ErrorAction SilentlyContinue) -ne "Test") {Start-Sleep -Seconds 5}
        $dcsession = New-PSSession -VMName $dcname -Credential $localadmin
        Write-LogEntry -Message "PowerShell Direct session for $($localadmin.UserName) has been initated with DC Service named: $dcname" -Type Information
        $dcnics = Invoke-Command -VMName $dcname -Credential $localadmin -ScriptBlock {Get-NetAdapter}
        Write-LogEntry -Message "The following network adaptors $($dcnics -join ",") have been found on: $dcname" -Type Information
        if (((Invoke-Pester -TestName "DC" -PassThru -show None).TestResult | Where-Object {$_.name -match "DC IP Address"}).result -notmatch "Passed") {
            Invoke-Command -Session $dcsession -ScriptBlock {param($t, $i) new-NetIPAddress -InterfaceIndex $t -AddressFamily IPv4 -IPAddress "$i`10" -PrefixLength 24 -DefaultGateway "$i`1"; Set-DnsClientServerAddress -ServerAddresses ('8.8.8.8') -InterfaceIndex $t} -ArgumentList $dcnics.InterfaceIndex, $ipsub | Out-Null
            Write-LogEntry -Message "IP Address $ipsub`.10 has been assigned to $DCName" -Type Information
        }
        if (((Invoke-Pester -TestName "DC" -PassThru -show None).TestResult | Where-Object {$_.name -match "DC Domain Services Installed"}).result -notmatch "Passed") {
            Invoke-Command -Session $dcsession -ScriptBlock {Install-WindowsFeature -Name DHCP, DNS, AD-Domain-Services} | Out-Null
            Write-LogEntry -Message "Domain Services roles have been enabled on $dcname" -Type Information
        }
        if (((Invoke-Pester -TestName "DC" -PassThru -show None).TestResult | Where-Object {$_.name -match "DC Promoted"}).result -notmatch "Passed") {
            Invoke-Command -Session $dcsession -ScriptBlock {param($d, $p)Install-ADDSForest -DomainName $d -SafeModeAdministratorPassword (ConvertTo-SecureString -string $p -asplaintext -Force) -confirm:$false -WarningAction SilentlyContinue} -ArgumentList $DomainFQDN, $admpwd | out-null
            Write-LogEntry -Message "Forrest $DomainFQDN has been promoted on $dcname" -Type Information
        }
        $dcsession | Remove-PSSession
        Write-LogEntry -Type Information -Message "PowerShell Direct Session for $dcname has been disconnected"
        while ((Invoke-Command -VMName $dcname -Credential $domuser {"Test"} -ErrorAction SilentlyContinue) -ne "Test") {Start-Sleep -Seconds 5}
        $dcsessiondom = New-PSSession -VMName $dcname -Credential $domuser
        Write-LogEntry -Message "PowerShell Direct session for $($domuser.UserName) has been initated with DC Service named: $dcname" -Type Information
        Invoke-Command -Session $dcsessiondom -ScriptBlock {Import-Module ActiveDirectory; $root = (Get-ADRootDSE).defaultNamingContext; if (!([adsi]::Exists("LDAP://CN=System Management,CN=System,$root"))) {$null= New-ADObject -Type Container -name "System Management" -Path "CN=System,$root" -Passthru}; $acl = get-acl "ad:CN=System Management,CN=System,$root"; new-adgroup -name "SCCM Servers" -groupscope Global; $objGroup = Get-ADGroup -filter {Name -eq "SCCM Servers"}; $All = [System.DirectoryServices.ActiveDirectorySecurityInheritance]::SelfAndChildren; $ace = new-object System.DirectoryServices.ActiveDirectoryAccessRule $objGroup.SID, "GenericAll", "Allow", $All; $acl.AddAccessRule($ace); Set-acl -aclobject $acl "ad:CN=System Management,CN=System,$root"}
        Write-LogEntry -Message "System Management Container created in $DomainFQDN forrest on $dcname" -type Information
        Write-LogEntry -Type Information -Message "Configuring DHCP Server"
        Invoke-Command -Session $dcsessiondom -ScriptBlock {param($domname, $iprange)Add-DhcpServerInDC; Add-DhcpServerv4Scope -name "$domname" -StartRange "$($iprange).100" -EndRange "$($iprange).150" -SubnetMask "255.255.255.0"} -ArgumentList $domainnetbios, $ipsub | Out-Null
        Write-LogEntry -Type Information -Message "DHCP Scope has been configured for $($ipsub).100 to $($ipsub).150 with a mask of 255.255.255.0"
        $dcsessiondom | Remove-PSSession
    }
    Write-LogEntry -Message "DC Server Completed: $(Get-Date)" -Type Information
    invoke-pester -TestName "DC"
}

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
        [parameter(Mandatory=$false)]
        [switch]
        $vmSnapshotenabled
    )
    Write-logentry -message "CM Server Started: $(Get-Date)" -type information
    $cmname = "$($envconfig.env)`CM"
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
            if($vmSnapshotenabled.IsPresent){
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
            $null = Invoke-Command -session $cmsessionLA -ScriptBlock {param($t, $i) new-NetIPAddress -InterfaceIndex $t -AddressFamily IPv4 -IPAddress "$i`11" -PrefixLength 24 -DefaultGateway "$i`1"; Set-DnsClientServerAddress -ServerAddresses ("$i`10") -InterfaceIndex $t} -ArgumentList $cmnics.InterfaceIndex, $ipsub
            write-logentry -message "IP Address $ipsub`.11 has been assigned to $cmname" -type information
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
            Invoke-Command -session $cmsession -ScriptBlock {Add-WindowsFeature BITS, BITS-IIS-Ext, BITS-Compact-Server, Web-Server, Web-WebServer, Web-Common-Http, Web-Default-Doc, Web-Dir-Browsing, Web-Http-Errors, Web-Static-Content, Web-Http-Redirect, Web-App-Dev, Web-Net-Ext, Web-Net-Ext45, Web-ASP, Web-Asp-Net, Web-Asp-Net45, Web-CGI, Web-ISAPI-Ext, Web-ISAPI-Filter, Web-Health, Web-Http-Logging, Web-Custom-Logging, Web-Log-Libraries, Web-Request-Monitor, Web-Http-Tracing, Web-Performance, Web-Stat-Compression, Web-Security, Web-Filtering, Web-Basic-Auth, Web-IP-Security, Web-Url-Auth, Web-Windows-Auth, Web-Mgmt-Tools, Web-Mgmt-Console, Web-Mgmt-Compat, Web-Metabase, Web-Lgcy-Mgmt-Console, Web-Lgcy-Scripting, Web-WMI, Web-Scripting-Tools, Web-Mgmt-Service, RDC} | Out-Null
            write-logentry -message "Windows Features enabled on $cmname" -type information
        }
        if (((Invoke-Pester -TestName "CM" -PassThru -show None).TestResult | Where-Object {$_.name -match "CM SQL Instance is installed"}).result -notmatch "Passed") {
            Add-VMDvdDrive -VMName $cmname -ControllerNumber 0 -ControllerLocation 1
            Set-VMDvdDrive -Path $config.SQLISO -VMName $cmname -ControllerNumber 0 -ControllerLocation 1
            $sqldisk = Invoke-Command -session $cmsession -ScriptBlock {(Get-PSDrive -PSProvider FileSystem | where-object {$_.name -ne "c"}).root}
            write-logentry -message "$($config.sqliso) mounted as $sqldisk to $cmname" -type information
            $SQLHash = @{'ACTION' = '"Install"';
                'SUPPRESSPRIVACYSTATEMENTNOTICE' = '"TRUE"';
                'IACCEPTROPENLICENSETERMS' = '"TRUE"';
                'ENU' = '"TRUE"';
                'QUIET' = '"TRUE"';
                'UpdateEnabled' = '"TRUE"';
                'USEMICROSOFTUPDATE' = '"TRUE"';
                'FEATURES' = 'SQLENGINE,RS';
                'UpdateSource' = '"MU"';
                'HELP' = '"FALSE"';
                'INDICATEPROGRESS' = '"FALSE"';
                'X86' = '"FALSE"';
                'INSTANCENAME' = '"MSSQLSERVER"';
                'INSTALLSHAREDDIR' = '"C:\Program Files\Microsoft SQL Server"';
                'INSTALLSHAREDWOWDIR' = '"C:\Program Files (x86)\Microsoft SQL Server"';
                'INSTANCEID' = '"MSSQLSERVER"';
                'RSINSTALLMODE' = '"DefaultNativeMode"';
                'SQLTELSVCACCT' = '"NT Service\SQLTELEMETRY"';
                'SQLTELSVCSTARTUPTYPE' = '"Automatic"';
                'INSTANCEDIR' = '"C:\Program Files\Microsoft SQL Server"';
                'AGTSVCACCOUNT' = '"NT Service\SQLSERVERAGENT"';
                'AGTSVCSTARTUPTYPE' = '"Manual"';
                'COMMFABRICPORT' = '"0"';
                'COMMFABRICNETWORKLEVEL' = '"0"';
                'COMMFABRICENCRYPTION' = '"0"';
                'MATRIXCMBRICKCOMMPORT' = '"0"';
                'SQLSVCSTARTUPTYPE' = '"Automatic"';
                'FILESTREAMLEVEL' = '"0"';
                'ENABLERANU' = '"FALSE"';
                'SQLCOLLATION' = '"SQL_Latin1_General_CP1_CI_AS"';
                'SQLSVCACCOUNT' = """$domainnetbios\administrator"""; 
                'SQLSVCPASSWORD' = """$admpwd""" 
                'SQLSVCINSTANTFILEINIT' = '"FALSE"';
                'SQLSYSADMINACCOUNTS' = """$domainnetbios\administrator"" ""$domainnetbios\Domain Users"""; 
                'SQLTEMPDBFILECOUNT' = '"1"';
                'SQLTEMPDBFILESIZE' = '"8"';
                'SQLTEMPDBFILEGROWTH' = '"64"';
                'SQLTEMPDBLOGFILESIZE' = '"8"';
                'SQLTEMPDBLOGFILEGROWTH' = '"64"';
                'ADDCURRENTUSERASSQLADMIN' = '"FALSE"';
                'TCPENABLED' = '"1"';
                'NPENABLED' = '"1"';
                'BROWSERSVCSTARTUPTYPE' = '"Disabled"';
                'RSSVCACCOUNT' = '"NT Service\ReportServer"';
                'RSSVCSTARTUPTYPE' = '"Automatic"';
            }
            $SQLHASHINI = @{'OPTIONS' = $SQLHash}
            $SQLInstallINI = ""
            Foreach ($i in $SQLHASHINI.keys) {
                $SQLInstallINI += "[$i]`r`n"
                foreach ($j in $($SQLHASHINI[$i].keys | Sort-Object)) {
                    $SQLInstallINI += "$j=$($SQLHASHINI[$i][$j])`r`n"
                }
                $SQLInstallINI += "`r`n"
            }
            write-logentry -message "SQL Configuration for $cmname is: $sqlinstallini" -type information
            Invoke-Command -Session $cmsession -ScriptBlock {param($ini) new-item -ItemType file -Path c:\ConfigurationFile.INI -Value $INI -Force} -ArgumentList $SQLInstallINI | out-null
            write-logentry -message "SQL installation has started on $cmname this can take some time" -type information
            Invoke-Command -Session $cmsession -ScriptBlock {param($drive)start-process -FilePath "$drive`Setup.exe" -Wait -ArgumentList "/ConfigurationFile=c:\ConfigurationFile.INI /IACCEPTSQLSERVERLICENSETERMS"} -ArgumentList $sqldisk
            write-logentry -message "SQL installation has completed on $cmname told you it would take some time" -type information
            #Invoke-Command -Session $cmsession -ScriptBlock {Import-Module sqlps;$wmi = new-object ('Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer');$Np = $wmi.GetSmoObject("ManagedComputer[@Name='$env:computername']/ ServerInstance[@Name='MSSQLSERVER']/ServerProtocol[@Name='Np']");$Np.IsEnabled = $true;$Np.Alter();Get-Service mssqlserver | Restart-Service}
            Set-VMDvdDrive -VMName $cmname -Path $null
            write-logentry -message "SQL ISO dismounted from $cmname" -type information
        }
        if (((Invoke-Pester -TestName "CM" -PassThru -show None).TestResult | Where-Object {$_.name -match "CM ADK installed"}).result -notmatch "Passed") {
            write-logentry -message "ADK is installing on $cmname" -type information
            Invoke-Command -Session $cmsession -ScriptBlock {Start-Process -FilePath "c:\data\adk\adksetup.exe" -Wait -ArgumentList " /Features OptionId.DeploymentTools OptionId.WindowsPreinstallationEnvironment OptionId.ImagingAndConfigurationDesigner OptionId.UserStateMigrationTool /norestart /quiet /ceip off"}
            write-logentry -message "ADK is installed on $cmname" -type information
        }
        if (((Invoke-Pester -TestName "CM" -PassThru -show None).TestResult | Where-Object {$_.name -match "CM SCCM Installed"}).result -notmatch "Passed") {
            $cmOSName = Invoke-Command -Session $cmsession -ScriptBlock {$env:COMPUTERNAME}
            write-logentry -message "Host name for $cmname is: $cmosname"
            $cmsitecode = "TP1"
            if ($config.SCCMVersion -eq "Prod") {
                $hashident = @{'action' = 'InstallPrimarySite'
                }
            }
            else {
                $hashident = @{'action' = 'InstallPrimarySite';
                    'Preview' = "1"
                }
            }
            $hashoptions = @{'ProductID' = 'EVAL';
                'SiteCode' = $cmsitecode;
                'SiteName' = "Tech Preview $cmsitecode";
                'SMSInstallDir' = 'C:\Program Files\Microsoft Configuration Manager';
                'SDKServer' = "$cmOSName.$DomainFQDN";
                'RoleCommunicationProtocol' = "HTTPorHTTPS";
                'ClientsUsePKICertificate' = "0";
                'PrerequisiteComp' = "$SCCMDLPreDown";
                'PrerequisitePath' = "C:\DATA\SCCM\DL";
                'ManagementPoint' = "$cmOSName.$DomainFQDN";
                'ManagementPointProtocol' = "HTTP";
                'DistributionPoint' = "$cmOSName.$DomainFQDN";
                'DistributionPointProtocol' = "HTTP";
                'DistributionPointInstallIIS' = "0";
                'AdminConsole' = "1";
                'JoinCEIP' = "0";
            }
            $hashSQL = @{'SQLServerName' = "$cmOSName.$DomainFQDN";
                'DatabaseName' = "CM_$cmsitecode";
                'SQLSSBPort' = '1433'
            }
            $hashCloud = @{
                'CloudConnector' = "1";
                'CloudConnectorServer' = "$cmOSName.$DomainFQDN"
            }
            $hashSCOpts = @{
            }
            $hashHierarchy = @{
    
            }
            $HASHCMInstallINI = @{'Identification' = $hashident;
                'Options' = $hashoptions;
                'SQLConfigOptions' = $hashSQL;
                'CloudConnectorOptions' = $hashCloud;
                'SystemCenterOptions' = $hashSCOpts;
                'HierarchyExpansionOption' = $hashHierarchy
            }
            $CMInstallINI = ""
            Foreach ($i in $HASHCMInstallINI.keys) {
                $CMInstallINI += "[$i]`r`n"
                foreach ($j in $($HASHCMInstallINI[$i].keys | Sort-Object)) {
                    $CMInstallINI += "$j=$($HASHCMInstallINI[$i][$j])`r`n"
                }
                $CMInstallINI += "`r`n"
            }
            write-logentry -message "CM install ini for $cmname is: $cminstallini" -type information
            Invoke-Command -Session $cmsession -ScriptBlock {param($ini) new-item -ItemType file -Path c:\CMinstall.ini -Value $INI -Force} -ArgumentList $CMInstallINI | out-null
            invoke-command -Session $cmsession -scriptblock {start-process -filepath "c:\data\sccm\smssetup\bin\x64\extadsch.exe" -wait}
            write-logentry -message "AD Schema has been exteded for SCCM on $domainfqdn"
            write-logentry -message "SCCM installation process has started on $cmname this will take some time so grab a coffee" -type information
            Invoke-Command -Session $cmsession -ScriptBlock {Start-Process -FilePath "C:\DATA\SCCM\SMSSETUP\bin\x64\setup.exe" -ArgumentList "/script c:\CMinstall.ini"}
            while ((invoke-command -Session $cmsession -ScriptBlock {get-content C:\ConfigMgrSetup.log | Select-Object -last 1 | Where-Object {$_ -like 'ERROR: Failed to ExecuteConfigureServiceBrokerSp*'}}).count -eq 0) {
                start-sleep -seconds 15
            }
            Start-Sleep -Seconds 30
            while ((invoke-command -Session $cmsession -ScriptBlock {get-content C:\ConfigMgrSetup.log | Select-Object -last 1 | Where-Object {$_ -like 'ERROR: Failed to ExecuteConfigureServiceBrokerSp*'}}).count -eq 0) {
                start-sleep -seconds 15
            }
            Invoke-Command -Session $cmsession -ScriptBlock {Get-Process setupwpf | Stop-Process -Force}
            write-logentry -message "SCCM has been installed on $cmname" -type information
            Invoke-Command -Session $cmsession -ScriptBlock {start-process C:\data\SCCM\SMSSETUP\BIN\I386\ConsoleSetup.exe -ArgumentList '/q TargetDir="C:\Program Files (x86)\Microsoft Configuration Manager" DefaultSiteServerName=localhost' -Wait}
            Write-LogEntry -Message "SCCM Console has been installed on $cmname" -Type Information
            $cmsession | remove-PSSession
            write-logentry -message "Powershell Direct session for $($domuser.username) on $cmname has been disposed" -type information
        }
    }
    Invoke-Pester -TestName "CM"
    Write-Output "CM Server Completed: $(Get-Date)"
    write-logentry -message "SCCM Server installation has completed on $cmname" -type information
}

function new-CAServer {
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
        [parameter(Mandatory=$false)]
        [switch]
        $vmSnapshotenabled
    )
    Write-LogEntry -Message "CA Server Started: $(Get-Date)" -Type Information
    $cAname = "$($envconfig.env)`CA"
    Write-LogEntry -Message "New CA server name is: $cAname" -Type Information
    $cAvhdx = "$vmpath\$($cAname)c.vhdx"
    Write-LogEntry -Message "Path for the VHDX for $cAname is: $cAvhdx" -Type Information
    if (((Invoke-Pester -TestName "CA" -PassThru -show None).TestResult | Where-Object {$_.name -match "CA Should Exist"}).result -notmatch "Passed") {
        if (((Invoke-Pester -TestName "CA" -PassThru -show None).TestResult | Where-Object {$_.name -match "CA VHDX Should Exist"}).Result -match "Passed") {
            Write-LogEntry -Message "SA VHDX already exists at path: $cAvhdx Please clean up and Rerun. BUILD STOPPED" -Type Error
            throw "CA VHDX Already Exists at path: $CAVHDX Please clean up and Rerun."
        }
        else {
            Copy-Item -Path $RefVHDX -Destination $CAVHDX
            Write-LogEntry -Message "Reference VHDX $refVHDX has been copied to: $cavhdx" -Type Information
        }
        if (((Invoke-Pester -TestName "CA" -PassThru -show None).TestResult | Where-Object {$_.name -match "CA VHDX Should exist"}).Result -notmatch "Passed") {
            Write-LogEntry -Message "Error creating the VHDX for CA. BUILD STOPPED" -Type Error
            throw "Error Creating the VHDX for CA"
        }
        else {
            Write-LogEntry -Message "Starting to create CA Server" -Type Information
            new-vm -name $cAname -MemoryStartupBytes 4gb -VHDPath $cAvhdx -Generation 2 | Set-VMMemory -DynamicMemoryEnabled:$false 
            if($vmSnapshotenabled.IsPresent){
                set-vm -name $caname -checkpointtype Disabled
            }
            get-vm -name $cAname | Set-VMProcessor -Count 4
            Write-LogEntry -Message "$cAname has been created" -Type Information
            start-vm -Name $cAname
            Write-LogEntry -Message "CA Server named $caname has been started" -Type Information
            Get-VMNetworkAdapter -VMName $cAname | Connect-VMNetworkAdapter -SwitchName $swname
            Write-LogEntry -Message "vSwitch named $swname has been attached to $cAname" -Type Information
        }
        while ((Invoke-Command -VMName $cAname -Credential $localadmin {"Test"} -ErrorAction SilentlyContinue) -ne "Test") {Start-Sleep -Seconds 5}
        $cAsessionLA = New-PSSession -vmname $cAname -credential $localadmin
        Write-LogEntry -Message "PowerShell Direct session for $($localadmin.UserName) has been initiated to $cAname" -Type Information
        if ($null -eq $casessionLA) {throw "Issue with CA Local User Account"}
        $canics = Invoke-Command -session $casessionLA -ScriptBlock {Get-NetAdapter}
        Write-LogEntry -Message "Network Adaptor $($canics -join ",") were found on $cAname" -Type Information
        if (((Invoke-Pester -TestName "CA" -PassThru -show None).TestResult | Where-Object {$_.name -match "CA IP Address"}).result -notmatch "Passed") {
            $null = Invoke-Command -session $casessionLA -ScriptBlock {param($t, $i) new-NetIPAddress -InterfaceIndex $t -AddressFamily IPv4 -IPAddress "$i`12" -PrefixLength 24 -DefaultGateway "$i`1"; Set-DnsClientServerAddress -ServerAddresses ("$i`10") -InterfaceIndex $t} -ArgumentList $canics.InterfaceIndex, $ipsub
            Write-LogEntry -Message "IP Address $ipsub`.12 has been assigned to $cAname" -Type Information
            start-sleep 120
        }
        if (((Invoke-Pester -TestName "CA" -PassThru -show None).TestResult | Where-Object {$_.name -match "CA has access to $DomainFQDN"}).result -match "Passed") {
            while ((Invoke-Command -VMName $caname -Credential $localadmin {param($i)(test-netconnection "$i`10").pingsucceeded} -ArgumentList $ipsub -ErrorAction SilentlyContinue) -ne $true -and $stop -ne (get-date)) {Start-Sleep -Seconds 5}
            Invoke-Command -session $casessionLA -ErrorAction SilentlyContinue -ScriptBlock {param($env, $domuser) Clear-DnsClientCache; Add-Computer -DomainName $env -domainCredential $domuser -Restart; Start-Sleep -Seconds 15; Restart-Computer -Force -Delay 0} -ArgumentList $DomainFQDN, $domuser
            Write-LogEntry -Message "$cAname has been joined to $DomainFQDN" -Type Information
            $stop = (get-date).AddMinutes(5)
            while ((Invoke-Command -VMName $caname -Credential $domuser {"Test"} -ErrorAction SilentlyContinue) -ne "Test" -and $stop -ne (get-date)) {Start-Sleep -Seconds 5}
        }
        else {
            throw "CA Server can't resolve $DomainFQDN"
        }
        $casession = New-PSSession -VMName $cAname -Credential $domuser
        Write-LogEntry -Message "PowerShell Direct session for user $($domuser.UserName) has been initiated to $cAname" -Type Information
        if (((Invoke-Pester -TestName "CA" -PassThru -Show None).TestResult | Where-Object {$_.name -match "CA Feature is installed"}).result -notmatch "Passed") {
            Invoke-Command -session $casession -ScriptBlock {Add-WindowsFeature -Name Adcs-Cert-Authority}
            Write-LogEntry -Message "Cert Authority feature has been enabled on $caname" -Type Information
        }
        Invoke-Command -session $casession -ScriptBlock {Install-AdcsCertificationAuthority -CAType EnterpriseRootCa -CryptoProviderName "ECDSA_P256#Microsoft Software Key Storage Provider" -KeyLength 256 -HashAlgorithmName SHA256 -confirm:$false}
        Write-LogEntry -Message "Certificate Authority role has been installed on $cAname" -Type Information
        $casession | Remove-PSSession
        Write-LogEntry -Message "PowerShell Direct session for $($domuser.UserName) has been disconnected from $cAname" -Type Information
        Invoke-Pester -TestName "CA"
        Write-LogEntry -Message "Installation of CA Server named $cAname is completed" -Type Information
    }
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
#add CMServer to the SCCM Server AD group
#Configure Boundry
#Install SCCM Client on other VM's
#download Adventureworks DB from GitHub and put into the CMServer
#   - use CMServer SQL Instance to create dummy users
#   - install ADDS Powershell commandlets
#process to create x number of workstation clients
#Download and install SSMS
#Download and install VSCode
#process to create x number of dummy clients
#find a solution to ensure the latest TP is installed
}

function Write-LogEntry {
    [cmdletBinding()]
    param (
        [ValidateSet("Information", "Error")]
        $Type = "Information",
        [parameter(Mandatory = $true)]
        $Message
    )
    switch ($Type) {
        'Error' {
            $Severity = 3
            break;
        }
        'Information' {
            $Severity = 6
            break;
        }
    }
    $DateTime = New-Object -ComObject WbemScripting.SWbemDateTime
    $DateTime.SetVarDate($(Get-Date))
    $UtcValue = $DateTime.Value
    $UtcOffset = $UtcValue.Substring(21, $UtcValue.Length - 21)
    $scriptname = (Get-PSCallStack)[1]
    $logline = `
        "<![LOG[$message]LOG]!>" + `
        "<time=`"$(Get-Date -Format HH:mm:ss.fff)$($UtcOffset)`" " + `
        "date=`"$(Get-Date -Format M-d-yyyy)`" " + `
        "component=`"$($scriptname.Command)`" " + `
        "context=`"$([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)`" " + `
        "type=`"$Severity`" " + `
        "thread=`"$PID`" " + `
        "file=`"$($Scriptname.ScriptName)`">";
        
    $logline | Out-File -Append -Encoding utf8 -FilePath $Logfile -Force
    Write-Verbose $Message
}
#endregion

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
#endregion 

#region create VMs
new-ENV -domuser $domuser -vmpath $vmpath -RefVHDX $RefVHDX -config $config -swname $swname
new-RRASServer -vmpath $vmpath -RRASname $RRASname -RefVHDX $RefVHDX -localadmin $localadmin -swname $swname -ipsub $ipsub -vmSnapshotenabled:$vmsnapshot
new-DC -vmpath $vmpath -envconfig $envConfig -localadmin $localadmin -swname $swname -ipsub $ipsub -DomainFQDN $DomainFQDN -admpwd $admpwd -domuser $domuser -vmSnapshotenabled:$vmsnapshot
new-SCCMServer -envconfig $envConfig -vmpath $vmpath -localadmin $localadmin -ipsub $ipsub -DomainFQDN $DomainFQDN -domuser $domuser -config $config -admpwd $admpwd -domainnetbios $domainnetbios -cmsitecode $cmsitecode -SCCMDLPreDown $SCCMDLPreDown -vmSnapshotenabled:$vmsnapshot
new-CAServer -envconfig $envConfig -vmpath $vmpath -localadmin $localadmin -ipsub $ipsub -DomainFQDN $DomainFQDN -domuser $domuser -config $config -admpwd $admpwd -domainnetbios $domainnetbios -vmSnapshotenabled:$vmsnapshot
#endregion