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