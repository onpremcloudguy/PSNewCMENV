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
        while ((Invoke-Command -VMName $dcname -Credential $domuser {(get-command get-adgroup).count} -ErrorAction SilentlyContinue -passthru) -ne 1) {Start-Sleep -Seconds 5}
        while (((invoke-pester -testname "DC" -passthru -show none).testresult | where-object {$_.name -match "DC SCCM Servers Group"}).result -notmatch "Passed") {
            $dcsessiondom = New-PSSession -VMName $dcname -Credential $domuser
            Write-LogEntry -Message "PowerShell Direct session for $($domuser.UserName) has been initated with DC Service named: $dcname" -Type Information
            Invoke-Command -Session $dcsessiondom -ScriptBlock {Import-Module ActiveDirectory; New-ADGroup -Name "SCCM Servers" -GroupScope 1 -ErrorAction SilentlyContinue -WarningAction SilentlyContinue}
        }
        Invoke-Command -Session $dcsessiondom -ScriptBlock {$root = (Get-ADRootDSE).defaultNamingContext; if (!([adsi]::Exists("LDAP://CN=System Management,CN=System,$root"))) {$null= New-ADObject -Type Container -name "System Management" -Path "CN=System,$root" -Passthru}; $acl = get-acl "ad:CN=System Management,CN=System,$root"; $objGroup = Get-ADGroup -filter {Name -eq "SCCM Servers"}; $All = [System.DirectoryServices.ActiveDirectorySecurityInheritance]::SelfAndChildren; $ace = new-object System.DirectoryServices.ActiveDirectoryAccessRule $objGroup.SID, "GenericAll", "Allow", $All; $acl.AddAccessRule($ace); Set-acl -aclobject $acl "ad:CN=System Management,CN=System,$root"}
        Write-LogEntry -Message "System Management Container created in $DomainFQDN forrest on $dcname" -type Information
        Write-LogEntry -Type Information -Message "Configuring DHCP Server"
        Invoke-Command -Session $dcsessiondom -ScriptBlock {param($domname, $iprange)Add-DhcpServerInDC; Add-DhcpServerv4Scope -name "$domname" -StartRange "$($iprange)100" -EndRange "$($iprange)150" -SubnetMask "255.255.255.0"} -ArgumentList $domainnetbios, $ipsub | Out-Null
        Write-LogEntry -Type Information -Message "DHCP Scope has been configured for $($ipsub).100 to $($ipsub).150 with a mask of 255.255.255.0"
        $dcsessiondom | Remove-PSSession
    }
    Write-LogEntry -Message "DC Server Completed: $(Get-Date)" -Type Information
    invoke-pester -TestName "DC"
}
