function new-CAServer {
    param(
        [Parameter(ParameterSetName='CAClass')]
        [CA]
        $CAConfig,
        [Parameter(ParameterSetName='NoClass')]
        [string]
        $VHDXpath,
        [Parameter(ParameterSetName='NoClass')]
        [pscredential]
        $localadmin,
        [Parameter(ParameterSetName='NoClass')]
        [string]
        $Network,
        [Parameter(ParameterSetName='NoClass')]
        [string]
        $ipAddress, 
        [Parameter(ParameterSetName='NoClass')]
        [string]
        $DomainFQDN,
        [Parameter(ParameterSetName='NoClass')]
        [pscredential]
        $domainuser,
        [parameter(ParameterSetName='NoClass',Mandatory=$false)]
        [switch]
        $vmSnapshotenabled,
        [Parameter(ParameterSetName='NoClass')]
        [int]
        $cores,
        [Parameter(ParameterSetName='NoClass')]
        [int]
        $ram,
        [Parameter(ParameterSetName='NoClass')]
        [string]
        $name,
        [Parameter(ParameterSetName='NoClass')]
        [string]
        $refvhdx,
        [Parameter(ParameterSetName='NoClass')]
        [string]
        $DCIP
    )
    if(!$PSBoundParameters.ContainsKey('CAConfig'))
    {
        $CAConfig = [CA]::new()
        $CAConfig.Name = $name
        $CAConfig.cores = $cores
        $CAConfig.ram = $ram
        $CAConfig.IPAddress = $ipAddress
        $CAConfig.network = $Network
        $CAConfig.VHDXpath = $VHDXpath
        $CAConfig.localadmin = $localadmin
        $CACOnfig.domainFQDN = $DomainFQDN
        $CAConfig.domainuser = $domainuser
        $CAConfig.VMSnapshotenabled = $vmSnapshotenabled.IsPresent
        $CAConfig.RefVHDX = $refvhdx
        $CAConfig.DCIP = $DCIP
    }
    $ipsubnet = $CAConfig.IPAddress.substring(0,($CAConfig.IPAddress.length - ([ipaddress] $CAConfig.IPAddress).GetAddressBytes()[3].count - 1))
    Write-LogEntry -Message "CA Server Started: $(Get-Date)" -Type Information
    Write-LogEntry -Message "CA Settings are: $($CAConfig | ConvertTo-Json)" -Type Information
    Write-LogEntry -Message "New CA server name is: $($caconfig.name)" -Type Information
    Write-LogEntry -Message "Path for the VHDX for $($CAConfig.name) is: $($CAConfig.VHDXpath)" -Type Information
    if (((Invoke-Pester -TestName "CA" -PassThru -show None).TestResult | Where-Object {$_.name -match "CA Should Exist"}).result -notmatch "Passed") {
        if (((Invoke-Pester -TestName "CA" -PassThru -show None).TestResult | Where-Object {$_.name -match "CA VHDX Should Exist"}).Result -match "Passed") {
            Write-LogEntry -Message "SA VHDX already exists at path: $($CAConfig.VHDXpath) Please clean up and Rerun. BUILD STOPPED" -Type Error
            throw "CA VHDX Already Exists at path: $($CAConfig.VHDXpath) Please clean up and Rerun."
        }
        else {
            Copy-Item -Path $CAConfig.RefVHDX -Destination $CAConfig.VHDXpath
            Write-LogEntry -Message "Reference VHDX $($CAConfig.RefVHDX) has been copied to: $($CAConfig.VHDXpath)" -Type Information
        }
        if (((Invoke-Pester -TestName "CA" -PassThru -show None).TestResult | Where-Object {$_.name -match "CA VHDX Should exist"}).Result -notmatch "Passed") {
            Write-LogEntry -Message "Error creating the VHDX for CA. BUILD STOPPED" -Type Error
            throw "Error Creating the VHDX for CA"
        }
        else {
            Write-LogEntry -Message "Starting to create CA Server" -Type Information
            $vm = new-vm -name $cAconfig.name -MemoryStartupBytes ($CAConfig.ram * 1gb) -VHDPath $CAConfig.VHDXpath -Generation 2 | Set-VMMemory -DynamicMemoryEnabled:$false
            $vm | Set-VMProcessor -Count $CAConfig.cores
            if(!($CAConfig.VMSnapshotenabled)){
                set-vm -name $caconfig.name -checkpointtype Disabled
            }
            Write-LogEntry -Message "$($cAconfig.name) has been created" -Type Information
            start-vm -Name $cAconfig.name
            Write-LogEntry -Message "CA Server named $($caconfig.name) has been started" -Type Information
            Get-VMNetworkAdapter -VMName $cAconfig.name | Connect-VMNetworkAdapter -SwitchName $CAConfig.network
            Write-LogEntry -Message "vSwitch named $($CAConfig.network) has been attached to $($cAconfig.name)" -Type Information
        }
        while ((Invoke-Command -VMName $cAconfig.name -Credential $CAConfig.localadmin {"Test"} -ErrorAction SilentlyContinue) -ne "Test") {Start-Sleep -Seconds 5}
        $cAsessionLA = New-PSSession -vmname $cAconfig.name -credential $CAConfig.localadmin
        Write-LogEntry -Message "PowerShell Direct session for $($CAConfig.localadmin.UserName) has been initiated to $($cAconfig.name)" -Type Information
        if ($null -eq $casessionLA) {throw "Issue with CA Local User Account"}
        $canics = Invoke-Command -session $casessionLA -ScriptBlock {Get-NetAdapter}
        Write-LogEntry -Message "Network Adaptor $($canics -join ",") were found on $($cAconfig.name)" -Type Information
        if (((Invoke-Pester -TestName "CA" -PassThru -show None).TestResult | Where-Object {$_.name -match "CA IP Address"}).result -notmatch "Passed") {
            $IPGateway = "$ipsubnet`1"
            $null = Invoke-Command -session $casessionLA -ScriptBlock {param($t, $i, $g, $d) new-NetIPAddress -InterfaceIndex $t -AddressFamily IPv4 -IPAddress "$i" -PrefixLength 24 -DefaultGateway "$g"; Set-DnsClientServerAddress -ServerAddresses ($d) -InterfaceIndex $t} -ArgumentList $canics.InterfaceIndex, $caconfig.ipaddress, $IPGateway, $CAConfig.DCIP | Out-Null
            Write-LogEntry -Message "IP Address $($CAConfig.IPAddress) has been assigned to $($cAconfig.name)" -Type Information
            start-sleep 120
        }
        if (((Invoke-Pester -TestName "CA" -PassThru -show None).TestResult | Where-Object {$_.name -match "CA has access to $($CACOnfig.domainFQDN)"}).result -match "Passed") {
            while ((Invoke-Command -VMName $caconfig.name -Credential $CAConfig.localadmin {param($i)(test-netconnection "$i`10" -ErrorAction SilentlyContinue).pingsucceeded} -ArgumentList $ipsub -ErrorAction SilentlyContinue) -ne $true -and $stop -ne (get-date)) {Start-Sleep -Seconds 5}
            Invoke-Command -session $casessionLA -ErrorAction SilentlyContinue -ScriptBlock {param($env, $DU) Clear-DnsClientCache; Add-Computer -DomainName $env -domainCredential $DU -Restart; Start-Sleep -Seconds 15; Restart-Computer -Force -Delay 0} -ArgumentList $CACOnfig.domainFQDN, $CAConfig.domainuser
            Write-LogEntry -Message "$($cAconfig.name) has been joined to $($CACOnfig.domainFQDN)" -Type Information
            $stop = (get-date).AddMinutes(5)
            while ((Invoke-Command -VMName $caconfig.name -Credential $CAConfig.domainuser {"Test"} -ErrorAction SilentlyContinue) -ne "Test" -and $stop -ne (get-date)) {Start-Sleep -Seconds 5}
        }
        else {
            throw "CA Server can't resolve $($CACOnfig.domainFQDN)"
        }
        $casession = New-PSSession -VMName $cAconfig.name -Credential $CAConfig.domainuser
        Write-LogEntry -Message "PowerShell Direct session for user $($CAConfig.domainuser.UserName) has been initiated to $($cAconfig.name)" -Type Information
        if (((Invoke-Pester -TestName "CA" -PassThru -Show None).TestResult | Where-Object {$_.name -match "CA Feature is installed"}).result -notmatch "Passed") {
            Invoke-Command -session $casession -ScriptBlock {Add-WindowsFeature -Name Adcs-Cert-Authority}
            Write-LogEntry -Message "Cert Authority feature has been enabled on $($caconfig.name)" -Type Information
        }
        Invoke-Command -session $casession -ScriptBlock {Install-AdcsCertificationAuthority -CAType EnterpriseRootCa -CryptoProviderName "ECDSA_P256#Microsoft Software Key Storage Provider" -KeyLength 256 -HashAlgorithmName SHA256 -confirm:$false | Out-Null}
        Write-LogEntry -Message "Certificate Authority role has been installed on $($cAconfig.name)" -Type Information
        $casession | Remove-PSSession
        Write-LogEntry -Message "PowerShell Direct session for $($CAConfig.domainuser.UserName) has been disconnected from $($cAconfig.name)" -Type Information
        Invoke-Pester -TestName "CA"
        Write-LogEntry -Message "Installation of CA Server named $($cAconfig.name) is completed" -Type Information
    }
}
