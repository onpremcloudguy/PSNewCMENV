function new-DC {
    param(
        [Parameter(ParameterSetName='DCClass')]
        [DC]
        $DCConfig,
        [Parameter(ParameterSetName='NoClass')]
        [string]
        $VHDXpath, # needs to be full path now
        [Parameter(ParameterSetName='NoClass')]
        [psobject]
        $envconfig, # refactor to remove this and pass just the servername
        [Parameter(ParameterSetName='NoClass')]
        [pscredential]
        $localadmin,
        [Parameter(ParameterSetName='NoClass')]
        [string]
        $Network,
        [Parameter(ParameterSetName='NoClass')]
        [string]
        $ipAddress, #Need to refactor IP address to be passed to function, Split and remove last octet to set gateway and DNS where required
        [Parameter(ParameterSetName='NoClass')]
        [string]
        $DomainFQDN,
        [Parameter(ParameterSetName='NoClass')]
        [string]
        $admpwd,
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
        $refvhdx
    )
    if(!$PSBoundParameters.ContainsKey('DCConfig'))
    {
        $DCconfig = [DC]::new()
        $dcconfig.AdmPwd = $admpwd
        $dcconfig.cores = $cores
        $dcconfig.Ram = $ram
        $dcconfig.IPAddress = $ipAddress
        $dcconfig.Name = $name
        $dcconfig.network = $Network
        $dcconfig.VHDXpath = $VHDXpath
        $dcconfig.localadmin = $localadmin
        $dcconfig.domainFQDN = $DomainFQDN
        $dcconfig.domainuser = $domainuser
        $dcconfig.VMSnapshotenabled = $vmSnapshotenabled.IsPresent
        $DCConfig.refvhdx = $refvhdx
    }
    $ipsubnet = $dcconfig.IPAddress.substring(0,($dcconfig.IPAddress.length - ([ipaddress] $dcconfig.IPAddress).GetAddressBytes()[3].count - 1))
    Write-LogEntry -Message "DC Server Started: $(Get-Date)" -Type Information

    Write-LogEntry -Message "VM for DC will be named: $($dcconfig.name)" -type Information
    Write-LogEntry -Message "Path for the VHDX for $($dcconfig.name) is: $($dcconfig.VHDXpath)" -type information
    if (!((Invoke-Pester -TestName "DC" -PassThru -show None).TestResult | Where-Object {$_.name -match "DC Should Exist"}).result -notmatch "Passed") {
        write-logentry -message "DC for env: $($envconfig.env) doesn't exist, creating now" -Type Information
        if (((Invoke-Pester -TestName "DC" -PassThru -show None).TestResult | Where-Object {$_.name -match "DC VHDX Should Exist"}).Result -match "Passed") {
            Write-LogEntry -Message "DC VHDX Already Exists at path: $($dcconfig.VHDXpath) Please clean up and Rerun." -Type Error
            throw "DC VHDX Already Exists at path: $($dcconfig.VHDXpath) Please clean up and Rerun."
        }
        else {
            Copy-Item -Path $dcconfig.RefVHDX -Destination $dcconfig.VHDXpath
            Write-LogEntry -Message "Reference VHDX: $($dcconfig.refvhdx) has been copied to: $($dcconfig.VHDXpath)" -Type Information
        }
        if (((Invoke-Pester -TestName "DC" -PassThru -show None).TestResult | Where-Object {$_.name -match "DC VHDX Should exist"}).Result -notmatch "Passed") {
            Write-LogEntry -Message "Error Creating the VHDX for $($dcconfig.name). Build STOPPED" -Type Error 
            throw "Error Creating the VHDX for DC"
        }
        else {
            Write-LogEntry -Message "Starting to create $($dcconfig.name) server" -Type Information
            $vm = new-vm -Name $dcconfig.name -MemoryStartupBytes ($dcconfig.ram * 1Gb) -VHDPath $dcconfig.VHDXpath -Generation 2
            $vm | Set-VMProcessor -Count $dcconfig.cores
            Enable-VMIntegrationService -VMName $dcconfig.name -Name "Guest Service Interface"
            if(!($dcconfig.vmSnapshotenabled)){
                set-vm -name $dcconfig.name -checkpointtype Disabled
            }
            Write-LogEntry -Message "$($dcconfig.name) has been created" -Type Information
            start-vm -Name $dcconfig.name
            Write-LogEntry -Message "DC server named $($dcconfig.name) has been started"
        }
        Get-VMNetworkAdapter -vmname $dcconfig.name | Connect-VMNetworkAdapter -SwitchName $dcconfig.Network
        Write-LogEntry -Message "vSwitch $Network has been attached to $($dcconfig.name)" -Type Information
        while ((Invoke-Command -VMName $dcconfig.name -Credential $dcconfig.localadmin {"Test"} -ErrorAction SilentlyContinue) -ne "Test") {Start-Sleep -Seconds 5}
        $dcsession = New-PSSession -VMName $dcconfig.name -Credential $dcconfig.localadmin
        Write-LogEntry -Message "PowerShell Direct session for $($dcconfig.localadmin.UserName) has been initated with DC Service named: $($dcconfig.name)" -Type Information
        $dcnics = Invoke-Command -VMName $dcconfig.name -Credential $dcconfig.localadmin -ScriptBlock {Get-NetAdapter}
        Write-LogEntry -Message "The following network adaptors $($dcnics -join ",") have been found on: $($dcconfig.name)" -Type Information
        if (((Invoke-Pester -TestName "DC" -PassThru -show None).TestResult | Where-Object {$_.name -match "DC IP Address"}).result -notmatch "Passed") {
            $IPGateway = "$ipsubnet`1"
            Invoke-Command -Session $dcsession -ScriptBlock {param($t, $i, $g) new-NetIPAddress -InterfaceIndex $t -AddressFamily IPv4 -IPAddress "$i" -PrefixLength 24 -DefaultGateway "$g"; Set-DnsClientServerAddress -ServerAddresses ('8.8.8.8') -InterfaceIndex $t} -ArgumentList $dcnics.InterfaceIndex, $dcconfig.ipaddress, $IPGateway | Out-Null
            Write-LogEntry -Message "IP Address $($dcconfig.IPAddress) has been assigned to $($dcconfig.name)" -Type Information
        }
        if (((Invoke-Pester -TestName "DC" -PassThru -show None).TestResult | Where-Object {$_.name -match "DC Domain Services Installed"}).result -notmatch "Passed") {
            Invoke-Command -Session $dcsession -ScriptBlock {Install-WindowsFeature -Name DHCP, DNS, AD-Domain-Services} | Out-Null
            Write-LogEntry -Message "Domain Services roles have been enabled on $($dcconfig.name)" -Type Information
        }
        if (((Invoke-Pester -TestName "DC" -PassThru -show None).TestResult | Where-Object {$_.name -match "DC Promoted"}).result -notmatch "Passed") {
            Invoke-Command -Session $dcsession -ScriptBlock {param($d, $p)Install-ADDSForest -DomainName $d -SafeModeAdministratorPassword (ConvertTo-SecureString -string $p -asplaintext -Force) -confirm:$false -WarningAction SilentlyContinue} -ArgumentList $dcconfig.DomainFQDN, $dcconfig.admpwd | out-null
            Write-LogEntry -Message "Forrest $($dcconfig.DomainFQDN) has been promoted on $($dcconfig.name)" -Type Information
        }
        $dcsession | Remove-PSSession
        Write-LogEntry -Type Information -Message "PowerShell Direct Session for $($dcconfig.name) has been disconnected"
        while ((Invoke-Command -VMName $dcconfig.name -Credential $dcconfig.domainuser {(get-command get-adgroup).count} -ErrorAction SilentlyContinue) -ne 1) {Start-Sleep -Seconds 5}
        while (((invoke-pester -testname "DC" -passthru -show none).testresult | where-object {$_.name -match "DC SCCM Servers Group"}).result -notmatch "Passed") {
            $dcsessiondom = New-PSSession -VMName $dcconfig.name -Credential $dcconfig.domainuser -ErrorAction SilentlyContinue
            #Write-LogEntry -Message "PowerShell Direct session for $($dcconfig.domainuser.UserName) has been initated with DC Service named: $($dcconfig.name)" -Type Information
            Invoke-Command -Session $dcsessiondom -ScriptBlock {Import-Module ActiveDirectory; New-ADGroup -Name "SCCM Servers" -GroupScope 1 -ErrorAction SilentlyContinue -WarningAction SilentlyContinue}
        }
        Invoke-Command -Session $dcsessiondom -ScriptBlock {$root = (Get-ADRootDSE).defaultNamingContext; if (!([adsi]::Exists("LDAP://CN=System Management,CN=System,$root"))) {$null= New-ADObject -Type Container -name "System Management" -Path "CN=System,$root" -Passthru}; $acl = get-acl "ad:CN=System Management,CN=System,$root"; $objGroup = Get-ADGroup -filter {Name -eq "SCCM Servers"}; $All = [System.DirectoryServices.ActiveDirectorySecurityInheritance]::SelfAndChildren; $ace = new-object System.DirectoryServices.ActiveDirectoryAccessRule $objGroup.SID, "GenericAll", "Allow", $All; $acl.AddAccessRule($ace); Set-acl -aclobject $acl "ad:CN=System Management,CN=System,$root"}
        Write-LogEntry -Message "System Management Container created in $($dcconfig.DomainFQDN) forrest on $($dcconfig.name)" -type Information
        Write-LogEntry -Type Information -Message "Configuring DHCP Server"
        Invoke-Command -Session $dcsessiondom -ScriptBlock {param($domname, $iprange)Add-DhcpServerInDC; Add-DhcpServerv4Scope -name "$domname" -StartRange "$($iprange)100" -EndRange "$($iprange)150" -SubnetMask "255.255.255.0"} -ArgumentList $domainnetbios, $ipsubnet | Out-Null
        Write-LogEntry -Type Information -Message "DHCP Scope has been configured for $($ipsubnet)100 to $($ipsubnet)150 with a mask of 255.255.255.0"
        $dcsessiondom | Remove-PSSession
    }
    Write-LogEntry -Message "DC Server Completed: $(Get-Date)" -Type Information
    invoke-pester -TestName "DC"
}
