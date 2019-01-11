function new-DC {
    param(
        [Parameter(ParameterSetName='DCClass')]
        [DC]
        $DCConfig,
        [Parameter(ParameterSetName='NoClass')]
        [string]
        $VMHDXpath, # needs to be full path now
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
        [parameter(ParameterSetName='NoClass',Mandatory=$false)]
        [int]
        $cores,
        [parameter(ParameterSetName='NoClass',Mandatory=$false)]
        [int]
        $ram,
        [parameter(ParameterSetName='NoClass',Mandatory=$false)]
        [string]
        $name
    )
    if(!$PSBoundParameters.ContainsKey('DC'))
    {
        $DC = [DC]::new()
        $dc.AdmPwd = $admpwd
        $dc.cores = $cores
        $dc.Ram = $ram
        $dc.IPAddress = $ipAddress
        $dc.Name = $name
        $dc.network = $Network
        $dc.VMHDXpath = $VMHDXpath
        $dc.localadmin = $localadmin
        $dc.domainFQDN = $DomainFQDN
        $dc.domainuser = $domainuser
        $dc.VMSnapshotenabled = $vmSnapshotenabled
    }
    $ipsubnet = $dc.IPAddress.substring(0,($dc.IPAddress.length - ([ipaddress] $dc.IPAddress).GetAddressBytes()[3].count - 1))
    Write-LogEntry -Message "DC Server Started: $(Get-Date)" -Type Information
    #$dc.name = "$($envconfig.env)`DC"
    #$dcvhdx = "$vmpath\$($dc.name)c.vhdx"

    Write-LogEntry -Message "VM for DC will be named: $($dc.name)" -type Information
    Write-LogEntry -Message "Path for the VHDX for $($dc.name) is: $($dc.VMHDXpath)" -type information
    if (!((Invoke-Pester -TestName "DC" -PassThru -show None).TestResult | Where-Object {$_.name -match "DC Should Exist"}).result -notmatch "Passed") {
        write-logentry -message "DC for env: $($envconfig.env) doesn't exist, creating now" -Type Information
        if (((Invoke-Pester -TestName "DC" -PassThru -show None).TestResult | Where-Object {$_.name -match "DC VHDX Should Exist"}).Result -match "Passed") {
            Write-LogEntry -Message "DC VHDX Already Exists at path: $($dc.VMHDXpath) Please clean up and Rerun." -Type Error
            throw "DC VHDX Already Exists at path: $($dc.VMHDXpath) Please clean up and Rerun."
        }
        else {
            Copy-Item -Path $RefVHDX -Destination $dc.VMHDXpath
            Write-LogEntry -Message "Reference VHDX: $refvhdx has been copied to: $($dc.VMHDXpath)" -Type Information
        }
        if (((Invoke-Pester -TestName "DC" -PassThru -show None).TestResult | Where-Object {$_.name -match "DC VHDX Should exist"}).Result -notmatch "Passed") {
            Write-LogEntry -Message "Error Creating the VHDX for $($dc.name). Build STOPPED" -Type Error 
            throw "Error Creating the VHDX for DC"
        }
        else {
            Write-LogEntry -Message "Starting to create $($dc.name) server" -Type Information
            $vm = new-vm -Name $dc.name -MemoryStartupBytes ($dc.ram * 1Gb) -VHDPath $dc.VMHDXpath -Generation 2
            $vm | Set-VMProcessor -Count $cores
            Enable-VMIntegrationService -VMName $dc.name -Name "Guest Service Interface"
            if!(($dc.vmSnapshotenabled)){
                set-vm -name $dc.name -checkpointtype Disabled
            }
            Write-LogEntry -Message "$($dc.name) has been created" -Type Information
            start-vm -Name $dc.name
            Write-LogEntry -Message "DC server named $($dc.name) has been started"
        }
        Get-VMNetworkAdapter -vmname $dc.name | Connect-VMNetworkAdapter -SwitchName $dc.Network
        Write-LogEntry -Message "vSwitch $Network has been attached to $($dc.name)" -Type Information
        while ((Invoke-Command -VMName $dc.name -Credential $dc.localadmin {"Test"} -ErrorAction SilentlyContinue) -ne "Test") {Start-Sleep -Seconds 5}
        $dcsession = New-PSSession -VMName $dc.name -Credential $dc.localadmin
        Write-LogEntry -Message "PowerShell Direct session for $($dc.localadmin.UserName) has been initated with DC Service named: $($dc.name)" -Type Information
        $dcnics = Invoke-Command -VMName $dc.name -Credential $dc.localadmin -ScriptBlock {Get-NetAdapter}
        Write-LogEntry -Message "The following network adaptors $($dcnics -join ",") have been found on: $($dc.name)" -Type Information
        if (((Invoke-Pester -TestName "DC" -PassThru -show None).TestResult | Where-Object {$_.name -match "DC IP Address"}).result -notmatch "Passed") {
            $IPGateway = "$ipsubnet`.1"
            Invoke-Command -Session $dcsession -ScriptBlock {param($t, $i, $g) new-NetIPAddress -InterfaceIndex $t -AddressFamily IPv4 -IPAddress "$i" -PrefixLength 24 -DefaultGateway "$g"; Set-DnsClientServerAddress -ServerAddresses ('8.8.8.8') -InterfaceIndex $t} -ArgumentList $dcnics.InterfaceIndex, $dc.ipaddress, $IPGateway | Out-Null
            Write-LogEntry -Message "IP Address $($dc.IPAddress) has been assigned to $($dc.name)" -Type Information
        }
        if (((Invoke-Pester -TestName "DC" -PassThru -show None).TestResult | Where-Object {$_.name -match "DC Domain Services Installed"}).result -notmatch "Passed") {
            Invoke-Command -Session $dcsession -ScriptBlock {Install-WindowsFeature -Name DHCP, DNS, AD-Domain-Services} | Out-Null
            Write-LogEntry -Message "Domain Services roles have been enabled on $($dc.name)" -Type Information
        }
        if (((Invoke-Pester -TestName "DC" -PassThru -show None).TestResult | Where-Object {$_.name -match "DC Promoted"}).result -notmatch "Passed") {
            Invoke-Command -Session $dcsession -ScriptBlock {param($d, $p)Install-ADDSForest -DomainName $d -SafeModeAdministratorPassword (ConvertTo-SecureString -string $p -asplaintext -Force) -confirm:$false -WarningAction SilentlyContinue} -ArgumentList $dc.DomainFQDN, $dc.admpwd | out-null
            Write-LogEntry -Message "Forrest $($dc.DomainFQDN) has been promoted on $($dc.name)" -Type Information
        }
        $dcsession | Remove-PSSession
        Write-LogEntry -Type Information -Message "PowerShell Direct Session for $($dc.name) has been disconnected"
        while ((Invoke-Command -VMName $dc.name -Credential $dc.domainuser {(get-command get-adgroup).count} -ErrorAction SilentlyContinue -passthru) -ne 1) {Start-Sleep -Seconds 5}
        while (((invoke-pester -testname "DC" -passthru -show none).testresult | where-object {$_.name -match "DC SCCM Servers Group"}).result -notmatch "Passed") {
            $dcsessiondom = New-PSSession -VMName $dc.name -Credential $dc.domainuser
            Write-LogEntry -Message "PowerShell Direct session for $($dc.domainuser.UserName) has been initated with DC Service named: $($dc.name)" -Type Information
            Invoke-Command -Session $dcsessiondom -ScriptBlock {Import-Module ActiveDirectory; New-ADGroup -Name "SCCM Servers" -GroupScope 1 -ErrorAction SilentlyContinue -WarningAction SilentlyContinue}
        }
        Invoke-Command -Session $dcsessiondom -ScriptBlock {$root = (Get-ADRootDSE).defaultNamingContext; if (!([adsi]::Exists("LDAP://CN=System Management,CN=System,$root"))) {$null= New-ADObject -Type Container -name "System Management" -Path "CN=System,$root" -Passthru}; $acl = get-acl "ad:CN=System Management,CN=System,$root"; $objGroup = Get-ADGroup -filter {Name -eq "SCCM Servers"}; $All = [System.DirectoryServices.ActiveDirectorySecurityInheritance]::SelfAndChildren; $ace = new-object System.DirectoryServices.ActiveDirectoryAccessRule $objGroup.SID, "GenericAll", "Allow", $All; $acl.AddAccessRule($ace); Set-acl -aclobject $acl "ad:CN=System Management,CN=System,$root"}
        Write-LogEntry -Message "System Management Container created in $($dc.DomainFQDN) forrest on $($dc.name)" -type Information
        Write-LogEntry -Type Information -Message "Configuring DHCP Server"
        Invoke-Command -Session $dcsessiondom -ScriptBlock {param($domname, $iprange)Add-DhcpServerInDC; Add-DhcpServerv4Scope -name "$domname" -StartRange "$($iprange)100" -EndRange "$($iprange)150" -SubnetMask "255.255.255.0"} -ArgumentList $domainnetbios, $ipsubnet | Out-Null
        Write-LogEntry -Type Information -Message "DHCP Scope has been configured for $($ipsubnet)100 to $($ipsubnet)150 with a mask of 255.255.255.0"
        $dcsessiondom | Remove-PSSession
    }
    Write-LogEntry -Message "DC Server Completed: $(Get-Date)" -Type Information
    invoke-pester -TestName "DC"
}
