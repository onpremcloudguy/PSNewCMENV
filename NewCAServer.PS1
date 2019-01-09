
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
