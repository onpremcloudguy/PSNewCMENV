function new-RRASServer {
    param(
        [Parameter(ParameterSetName='RRASClass')]
        [RRAS]
        $RRASConfig,
        [Parameter(ParameterSetName='NoClass')]
        [string]
        $VHDXPath,
        [Parameter(ParameterSetName='NoClass')]
        [string]
        $RefVHDX,
        [Parameter(ParameterSetName='NoClass')]
        [pscredential]
        $localadmin,
        [parameter(ParameterSetName='NoClass',Mandatory=$false)]
        [switch]
        $vmSnapshotenabled,
        [Parameter(ParameterSetName='NoClass')]
        [string]
        $Name,
        [Parameter(ParameterSetName='NoClass')]
        [int]
        $cores,
        [Parameter(ParameterSetName='NoClass')]
        [int]
        $RAM,
        [Parameter(ParameterSetName='NoClass')]
        [string]
        $IPaddress,
        [Parameter(ParameterSetName='NoClass')]
        [string]
        $network
    )
    if(!$PSBoundParameters.ContainsKey('RRASConfig'))
    {
        $RRASConfig = [RRAS]::new()
        $RRASConfig.Name = $name
        $RRASConfig.Cores = $cores
        $RRASConfig.Ram = $RAM
        $RRASConfig.ipaddress = $IPaddress
        $RRASConfig.Network = $network
        $RRASConfig.localadmin = $localadmin
        $RRASConfig.vmSnapshotenabled = $vmSnapshotenabled
        $RRASConfig.VHDXpath = $VHDXPath
        $RRASConfig.RefVHDX = $RefVHDX
    }
    Write-LogEntry -Message "RRAS Server started $(Get-Date)" -type Information
    Write-LogEntry -Message "RRAS Settings are: $($RRASConfig | ConvertTo-Json)" -Type Information
    if (((Invoke-Pester -TestName "RRAS" -PassThru -show None).TestResult | Where-Object {$_.name -match "RRAS Server Should exist"}).Result -notmatch "Passed") {
        Write-LogEntry -Type Information -Message "Path for the VHDX for RRAS is: $($RRASConfig.VHDXpath)"
        if (((Invoke-Pester -TestName "RRAS" -PassThru -show None).TestResult | Where-Object {$_.name -match "VHDX Should exist"}).Result -match "Passed") {
            Write-LogEntry -Type Error -Message "RRAS VHDX Already Exists at path: $($RRASConfig.VHDXpath) Please clean up and Rerun. Build STOPPED" 
            throw "RRAS VHDX Already Exists at path: $($RRASConfig.VHDXpath) Please clean up and Rerun."
        }
        else {
            Copy-Item -Path $RRASConfig.RefVHDX -Destination $RRASConfig.VHDXpath
            Write-LogEntry -Type Information -Message "Reference VHDX: $($RRASConfig.RefVHDX) has been copied to: $($RRASConfig.VHDXpath)"
        }
        if (((Invoke-Pester -TestName "RRAS" -PassThru -show None).TestResult | Where-Object {$_.name -match "VHDX Should exist"}).Result -notmatch "Passed") {
            Write-LogEntry -Type Error -Message "Error Creating the VHDX for RRAS. Build STOPPED"
            throw "Error Creating the VHDX for RRAS"
        }
        else {
            Write-LogEntry -Type Information -Message "Starting to create RRAS Server"
            $vm = new-vm -Name $RRASConfig.name -MemoryStartupBytes ($RRASConfig.RAM * 1Gb) -VHDPath $RRASConfig.VHDXpath -Generation 2 | out-null # | Set-VMMemory -DynamicMemoryEnabled:$false
            $vm | Set-VMProcessor -Count $RRASConfig.cores
            Enable-VMIntegrationService -VMName $RRASConfig.name -Name "Guest Service Interface"
            if(!$RRASConfig.vmSnapshotenabled){
                set-vm -Name $RRASConfig.name -CheckpointType Disabled
            }
            Write-LogEntry -Type Information -Message "RRAS Server has been created"
            if (((Invoke-Pester -TestName "RRAS" -PassThru -show None).TestResult | Where-Object {$_.name -match "RRAS Server Should exist"}).Result -notmatch "Passed") {Write-LogEntry -Type Error -message "Error Creating the VHDX for RRAS"; throw "Error Creating the VHDX for RRAS"}
        }
        start-vm -Name $RRASConfig.name
        Write-LogEntry -Type Information -Message "RRAS Server named $($RRASConfig.Name) has been started"
        Get-VMNetworkAdapter -vmname $RRASConfig.name | Connect-VMNetworkAdapter -SwitchName 'Internet' | Set-VMNetworkAdapter -Name 'Internet' -DeviceNaming On
        Write-LogEntry -Type Information -Message "vSwitch named Internet has been connected to the RRAS Server"
        while ((Invoke-Command -VMName $RRASConfig.name -Credential $RRASConfig.localadmin {"Test"} -ErrorAction SilentlyContinue) -ne "Test") {Start-Sleep -Seconds 5}
        $RRASConfigSession = New-PSSession -VMName $RRASConfig.name -Credential $RRASConfig.localadmin
        Write-LogEntry -Type Information -Message "PowerShell Direct session for $($RRASConfig.localadmin.UserName) has been initated with RRAS Server named: $($RRASConfig.name)"
        if (((Invoke-Pester -TestName "RRAS" -PassThru -show None).TestResult | Where-Object {$_.name -match "RRAS Routing Installed"}).Result -match "Passed") {
            Write-Verbose "RRAS Routing Already installed"
        }
        else {
            $null = Invoke-Command -Session $RRASConfigSession -ScriptBlock {Install-WindowsFeature Routing -IncludeManagementTools}
            Write-LogEntry -Type Information -Message "Routing and Remote Access services role now installed on: $($RRASConfig.name)"
            if (((Invoke-Pester -TestName "RRAS" -PassThru -show None).TestResult | Where-Object {$_.name -match "RRAS Routing Installed"}).Result -notmatch "Passed") {Write-LogEntry -Type Error -Message "Error installing RRAS Routing, Build STOPPED";throw "Error installing RRAS Routing"}
        }
        while ((Invoke-Command -VMName $RRASConfig.name -Credential $RRASConfig.localadmin {"Test"} -ErrorAction SilentlyContinue) -ne "Test") {Start-Sleep -Seconds 5}
        $RRASConfigSession = New-PSSession -VMName $RRASConfig.name -Credential $RRASConfig.localadmin
        Write-LogEntry -Type Information -Message "PowerShell Direct session for $($RRASConfig.localadmin.UserName) has been initated with RRAS Server named: $($RRASConfig.name)"
        if (((Invoke-Pester -TestName "RRAS" -PassThru -show None).TestResult | Where-Object {$_.name -match "RRAS External NIC Renamed"}).Result -match "Passed") {
            Write-Verbose "RRAS NIC Already Named external"
        }
        else {
            Invoke-Command -Session $RRASConfigSession -ScriptBlock {Get-NetAdapter -Physical -name Ethernet | rename-netadapter -newname "External" }
            Write-LogEntry -Type Information -Message "Renamed Network Adaptor to 'External'"
            if (((Invoke-Pester -TestName "RRAS" -PassThru -show None).TestResult | Where-Object {$_.name -match "RRAS External NIC Renamed"}).Result -notmatch "Passed") {write-logentry -Type Error -Message "RRAS NIC not renamed. Build STOPPED";throw "RRAS NIC not renamed"}
        }
        Invoke-Command -Session $RRASConfigSession -ScriptBlock {Install-RemoteAccess -VpnType Vpn; netsh routing ip nat install; netsh routing ip nat add interface "External"; netsh routing ip nat set interface "External" mode=full}
        Write-LogEntry -Type Information -Message "Routing configured for External Network adapter"
        $RRASConfigSession | Remove-PSSession
        Write-LogEntry -Type Information -Message "PowerShell Direct Session for $($RRASConfig.name) has been disconnected"
    }
    else {
        Start-VM $RRASConfig.name
        Write-LogEntry -Type Information -Message "Starting Routing and Remote Access Services server named: $($RRASConfig.Name)"
        while ((Invoke-Command -VMName $RRASConfig.name -Credential $RRASConfig.localadmin {"Test"} -ErrorAction SilentlyContinue) -ne "Test") {Start-Sleep -Seconds 5}
    }

    if ((Get-VMNetworkAdapter -VMName $RRASConfig.name | Where-Object {$_.switchname -eq $RRASConfig.network}).count -eq 0) {
        if (((Invoke-Pester -TestName "RRAS" -PassThru -show None).TestResult | Where-Object {$_.name -match "RRAS Lab IP Address Set"}).Result -match "Passed") {
            Write-Verbose "RRAS NIC Already Named $($RRASConfig.Network)"
        }
        else {
            $RRASConfigSession = New-PSSession -VMName $RRASConfig.name -Credential $RRASConfig.localadmin
            Write-LogEntry -Type Information -Message "PowerShell Direct session for $($RRASConfig.localadmin.UserName) has been initated with RRAS Server named: $($RRASConfig.name)"
            $RRASConfignics = Invoke-Command -Session $RRASConfigSession -ScriptBlock {Get-NetAdapter}
            Write-LogEntry -Type Information -Message "The following Network Adaptors $($RRASConfignics -join ",") have been found on: $($RRASConfig.name)"
            get-vm -Name $RRASConfig.name | Add-VMNetworkAdapter -SwitchName $RRASConfig.Network
            Write-LogEntry -Type Information -Message "Network adaptor for switch: $($RRASConfig.Network) has been added to: $($RRASConfig.Name)"
            Start-Sleep -Seconds 10
            $RRASConfignewnics = Invoke-Command -Session $RRASConfigSession -ScriptBlock {Get-NetAdapter}
            Write-LogEntry -Type Information -Message "The following Network Adaptors $($RRASConfignewnics -join ",") have been found on: $($RRASConfig.name)"
            $t = Compare-Object -ReferenceObject $RRASConfignics -DifferenceObject $RRASConfignewnics -PassThru
            $null = Invoke-Command -Session $RRASConfigSession -ScriptBlock {param($t, $i) new-NetIPAddress -InterfaceIndex $t -AddressFamily IPv4 -IPAddress "$i" -PrefixLength 24} -ArgumentList $t.InterfaceIndex, $rrasconfig.IPaddress
            Write-LogEntry -Type Information -Message "Ip address of $rrasconfig.IPAddress has been set on Network Adaptor $($RRASConfig.Network) for VM $($RRASConfig.Name)"
            Invoke-Command -Session $RRASConfigSession -ScriptBlock {param($n, $t)Get-NetAdapter -InterfaceIndex $n | rename-netadapter -newname $t } -ArgumentList $t.InterfaceIndex, $RRASConfig.Network
            Invoke-Command -Session $RRASConfigSession -ScriptBlock {param($n)get-service -name "remoteaccess" | Restart-Service -WarningAction SilentlyContinue; netsh routing ip nat add interface $n} -ArgumentList $RRASConfig.Network
            Write-LogEntry -Type Information -Message "Network adaptor renamed to: $($RRASConfig.Network) and Routing configured."
            if (((Invoke-Pester -TestName "RRAS" -PassThru -show None).TestResult | Where-Object {$_.name -match "RRAS Lab IP Address Set"}).Result -notmatch "Passed") {Write-LogEntry -Type Error -Message "Lab IP address not added. Build STOPPED";throw "Lab IP address not added"}
        }
        Invoke-Command -Session $RRASConfigSession -ScriptBlock {Set-LocalUser -Name "Administrator" -PasswordNeverExpires 1}
        Write-LogEntry -type Information -message "Local admin account set to not expire"
        Invoke-Command -Session $RRASConfigSession -ScriptBlock { Set-ItemProperty -path HKLM:\SOFTWARE\Microsoft\ServerManager -name DoNotOpenServerManagerAtLogon -Type DWord -value "1" -Force }
        $RRASConfigSession | Remove-PSSession
        Write-LogEntry -Type Information -Message "PowerShell Direct Session for $($RRASConfig.name) has been disconnected"
    }
    write-logentry -Type Information -Message "RRAS Server Completed: $(Get-Date)"
    invoke-pester -name "RRAS"
}