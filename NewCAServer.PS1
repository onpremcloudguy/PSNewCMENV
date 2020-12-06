function new-CAServer {
    param(
        [Parameter(ParameterSetName = 'CAClass')]
        [CA]
        $CAConfig,
        [Parameter(ParameterSetName = 'NoClass')]
        [string]
        $VHDXpath,
        [Parameter(ParameterSetName = 'NoClass')]
        [pscredential]
        $localadmin,
        [Parameter(ParameterSetName = 'NoClass')]
        [string]
        $Network,
        [Parameter(ParameterSetName = 'NoClass')]
        [string]
        $ipAddress, 
        [Parameter(ParameterSetName = 'NoClass')]
        [string]
        $DomainFQDN,
        [Parameter(ParameterSetName = 'NoClass')]
        [pscredential]
        $domainuser,
        [parameter(ParameterSetName = 'NoClass', Mandatory = $false)]
        [switch]
        $vmSnapshotenabled,
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
        $refvhdx,
        [Parameter(ParameterSetName = 'NoClass')]
        [string]
        $DCIP
    )
    if (!$PSBoundParameters.ContainsKey('CAConfig')) {
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
    $ipsubnet = $CAConfig.IPAddress.substring(0, ($CAConfig.IPAddress.length - ([ipaddress] $CAConfig.IPAddress).GetAddressBytes()[3].count - 1))
    Write-LogEntry -Message "CA Server Started: $(Get-Date)" -Type Information
    Write-LogEntry -Message "CA Settings are: $($CAConfig | ConvertTo-Json)" -Type Information
    Write-LogEntry -Message "New CA server name is: $($caconfig.name)" -Type Information
    Write-LogEntry -Message "Path for the VHDX for $($CAConfig.name) is: $($CAConfig.VHDXpath)" -Type Information
    if (((Invoke-Pester -TestName "CA" -PassThru -show None).TestResult | Where-Object { $_.name -match "CA Should Exist" }).result -notmatch "Passed") {
        if (((Invoke-Pester -TestName "CA" -PassThru -show None).TestResult | Where-Object { $_.name -match "CA VHDX Should Exist" }).Result -match "Passed") {
            Write-LogEntry -Message "SA VHDX already exists at path: $($CAConfig.VHDXpath) Please clean up and Rerun. BUILD STOPPED" -Type Error
            throw "CA VHDX Already Exists at path: $($CAConfig.VHDXpath) Please clean up and Rerun."
        }
        else {
            Copy-Item -Path $CAConfig.RefVHDX -Destination $CAConfig.VHDXpath
            Write-LogEntry -Message "Reference VHDX $($CAConfig.RefVHDX) has been copied to: $($CAConfig.VHDXpath)" -Type Information
        }
        if (((Invoke-Pester -TestName "CA" -PassThru -show None).TestResult | Where-Object { $_.name -match "CA VHDX Should exist" }).Result -notmatch "Passed") {
            Write-LogEntry -Message "Error creating the VHDX for CA. BUILD STOPPED" -Type Error
            throw "Error Creating the VHDX for CA"
        }
        else {
            Write-LogEntry -Message "Starting to create CA Server" -Type Information
            $vm = new-vm -name $cAconfig.name -MemoryStartupBytes ($CAConfig.ram * 1gb) -VHDPath $CAConfig.VHDXpath -Generation 2 | Set-VMMemory -DynamicMemoryEnabled:$false
            $vm | Set-VMProcessor -Count $CAConfig.cores
            if (!($CAConfig.VMSnapshotenabled)) {
                set-vm -name $caconfig.name -checkpointtype Disabled
            }
            Write-LogEntry -Message "$($cAconfig.name) has been created" -Type Information
            start-vm -Name $cAconfig.name
            Write-LogEntry -Message "CA Server named $($caconfig.name) has been started" -Type Information
            Get-VMNetworkAdapter -VMName $cAconfig.name | Connect-VMNetworkAdapter -SwitchName $CAConfig.network
            Write-LogEntry -Message "vSwitch named $($CAConfig.network) has been attached to $($cAconfig.name)" -Type Information
        }
        while ((Invoke-Command -VMName $cAconfig.name -Credential $CAConfig.localadmin { "Test" } -ErrorAction SilentlyContinue) -ne "Test") { Start-Sleep -Seconds 5 }
        $cAsessionLA = New-PSSession -vmname $cAconfig.name -credential $CAConfig.localadmin
        Write-LogEntry -Message "PowerShell Direct session for $($CAConfig.localadmin.UserName) has been initiated to $($cAconfig.name)" -Type Information
        if ($null -eq $casessionLA) { throw "Issue with CA Local User Account" }
        $canics = Invoke-Command -session $casessionLA -ScriptBlock { Get-NetAdapter }
        Write-LogEntry -Message "Network Adaptor $($canics -join ",") were found on $($cAconfig.name)" -Type Information
        if (((Invoke-Pester -TestName "CA" -PassThru -show None).TestResult | Where-Object { $_.name -match "CA IP Address" }).result -notmatch "Passed") {
            $IPGateway = "$ipsubnet`1"
            $null = Invoke-Command -session $casessionLA -ScriptBlock { param($t, $i, $g, $d) new-NetIPAddress -InterfaceIndex $t -AddressFamily IPv4 -IPAddress "$i" -PrefixLength 24 -DefaultGateway "$g"; Set-DnsClientServerAddress -ServerAddresses ($d) -InterfaceIndex $t } -ArgumentList $canics.InterfaceIndex, $caconfig.ipaddress, $IPGateway, $CAConfig.DCIP | Out-Null
            Write-LogEntry -Message "IP Address $($CAConfig.IPAddress) has been assigned to $($cAconfig.name)" -Type Information
            start-sleep 120
        }
        if (((Invoke-Pester -TestName "CA" -PassThru -show None).TestResult | Where-Object { $_.name -match "CA has access to $($CACOnfig.domainFQDN)" }).result -match "Passed") {
            while ((Invoke-Command -VMName $caconfig.name -Credential $CAConfig.localadmin { param($i)(test-netconnection "$i`10" -ErrorAction SilentlyContinue).pingsucceeded } -ArgumentList $ipsub -ErrorAction SilentlyContinue) -ne $true -and $stop -ne (get-date)) { Start-Sleep -Seconds 5 }
            Invoke-Command -session $casessionLA -ErrorAction SilentlyContinue -ScriptBlock { param($env, $DU) Clear-DnsClientCache; Add-Computer -DomainName $env -domainCredential $DU -Restart; Start-Sleep -Seconds 15; Restart-Computer -Force -Delay 0 } -ArgumentList $CACOnfig.domainFQDN, $CAConfig.domainuser
            Write-LogEntry -Message "$($cAconfig.name) has been joined to $($CACOnfig.domainFQDN)" -Type Information
            $stop = (get-date).AddMinutes(5)
            while ((Invoke-Command -VMName $caconfig.name -Credential $CAConfig.domainuser { "Test" } -ErrorAction SilentlyContinue) -ne "Test" -and $stop -ne (get-date)) { Start-Sleep -Seconds 5 }
        }
        else {
            throw "CA Server can't resolve $($CACOnfig.domainFQDN)"
        }
        $casession = New-PSSession -VMName $cAconfig.name -Credential $CAConfig.domainuser
        Write-LogEntry -Message "PowerShell Direct session for user $($CAConfig.domainuser.UserName) has been initiated to $($cAconfig.name)" -Type Information
        if (((Invoke-Pester -TestName "CA" -PassThru -Show None).TestResult | Where-Object { $_.name -match "CA Feature is installed" }).result -notmatch "Passed") {
            Invoke-Command -session $casession -ScriptBlock { Add-WindowsFeature -Name ADCS-Cert-Authority, ADCS-Web-Enrollment, Storage-Services, Web-Default-Doc, Web-Dir-Browsing, Web-Http-Errors, Web-Static-Content, Web-Http-Redirect, Web-Http-Logging, Web-Log-Libraries, Web-Request-Monitor, Web-Http-Tracing, Web-Stat-Compression, Web-Filtering, Web-Windows-Auth, Web-ASP, Web-ISAPI-Ext, Web-Mgmt-Console, Web-Metabase, NET-Framework-45-Core, NET-WCF-TCP-PortSharing45, RSAT-ADCS-Mgmt, RSAT-Online-Responder, RSAT-AD-PowerShell | Out-Null }
            Write-LogEntry -Message "Cert Authority feature has been enabled on $($caconfig.name)" -Type Information
        }
        # add new service account
        # grant service account permissions to the CA to manage certs
        
        Invoke-Command -Session $casession -ScriptBlock { Set-ItemProperty -path HKLM:\SOFTWARE\Microsoft\ServerManager -name DoNotOpenServerManagerAtLogon -Type DWord -value "1" -Force }
        Invoke-Command -session $casession -ScriptBlock { param($env)Install-AdcsCertificationAuthority -CAType EnterpriseRootCa -CryptoProviderName "RSA#Microsoft Software Key Storage Provider" -KeyLength 2048 -HashAlgorithmName SHA256 -validityPeriod Months -validityPeriodUnits 6 -CACommonName "$($env)-root" -confirm:$false | Out-Null } -ArgumentList $CAConfig.network
        Invoke-Command -session $casession -ScriptBlock { Install-AdcsWebEnrollment -Confirm:$false | Out-Null }
        Invoke-Command -session $casession -ScriptBlock { Get-CACrlDistributionPoint | Where-Object { $_.uri -like "http*" } | Remove-CACrlDistributionPoint -Confirm:$false | Out-Null }
        Invoke-Command -session $casession -ScriptBlock { Add-CACrlDistributionPoint -Uri "http://<ServerDNSName>/CertEnroll/<CAName><CRLNameSuffix><DeltaCRLAllowed>.crl" -AddToCertificateCdp -AddToFreshestCrl -AddToCrlIdp -Confirm:$false | Out-Null }
        Invoke-Command -session $casession -ScriptBlock { Get-CAAuthorityInformationAccess | Where-Object { $_.URI -like 'http:*' } | Remove-CAAuthorityInformationAccess -Confirm:$false | Out-Null }
        Invoke-Command -session $casession -ScriptBlock { Add-CAAuthorityInformationAccess -Uri "http://<ServerDNSName>/CertEnroll/<ServerDNSName>_<CAName><CertificateName>.crt" -AddToCertificateAia -Confirm:$false | Out-Null }
        Invoke-Command -session $casession -ScriptBlock { Get-Service -Name certsvc | Restart-Service | Out-Null }
        $ndessvcuser = "ndessvc"
        
        $KDCScriptBlock = [ScriptBlock]::create((get-command new-kdccert).Definition.Replace("`$domain", $domainnetbios))
        Invoke-Command -Session $casession -ScriptBlock $KDCScriptBlock
        $CCMWebScriptBlock = [ScriptBlock]::create((get-command new-ccmwebcert).Definition.Replace("`$domain", $domainnetbios).Replace("`$ndessvc",$ndessvcuser))
        Invoke-Command -Session $casession -ScriptBlock $CCMWebScriptBlock
        $NDESScriptBlock = [scriptblock]::Create((get-command new-NDESUsercert).Definition.Replace("`$domain", $domainnetbios).Replace("`$ndessvc",$ndessvcuser))
        Invoke-Command -Session $casession -ScriptBlock $NDESScriptBlock
        Invoke-Command -session $casession -ScriptBlock { Remove-CATemplate DomainControllerAuthentication -Confirm:$false }
        Invoke-Command -session $casession -ScriptBlock { Remove-CATemplate KerberosAuthentication -Confirm:$false }
        Invoke-Command -session $casession -ScriptBlock { Remove-CATemplate DomainController -Confirm:$false }
        Write-LogEntry -Message "Certificate Authority role has been installed on $($cAconfig.name)" -Type Information
        Invoke-Command -Session $casession -ScriptBlock { param($env)Get-ChildItem -Path Cert:\LocalMachine\Root | Where-Object { $_.subject -like "CN=$env*" } | Select-Object -Unique | Export-Certificate -FilePath c:\rootcert.cer | out-null } -ArgumentList $CAConfig.network
        Copy-Item -FromSession $casession -Path "C:\rootcert.cer" -Destination "$(split-path $CAConfig.VHDXpath)\rootcert.cer" | Out-Null
        Invoke-Command -Session $casession -ScriptBlock { param($env)Get-ChildItem -Path Cert:\LocalMachine\CA | Where-Object { $_.subject -like "CN=$env*" } | Select-Object -Unique | Export-Certificate -FilePath c:\intcert.cer | out-null } -ArgumentList $CAConfig.network
        Copy-Item -FromSession $casession -Path "C:\intcert.cer" -Destination "$(split-path $CAConfig.VHDXpath)\intcert.cer" | Out-Null
        $casession | Remove-PSSession

        $rootcert = "$vmpath\rootcert.cer"
        $intCert = "$vmpath\intcert.cer"
        $dcsessiondom = New-PSSession -VMName "$($caconfig.network)DC" -Credential $CAconfig.domainuser
        Copy-Item -ToSession $dcsessiondom -Path $rootcert -Destination "c:\rootcert.cer" | Out-Null
        copy-item -ToSession $dcsessiondom -Path $intCert -Destination "c:\intcert.cer" | Out-Null
        Invoke-Command -Session $dcsessiondom -ScriptBlock { Import-Certificate -FilePath C:\rootcert.cer -CertStoreLocation Cert:\LocalMachine\Root | out-null }
        Invoke-Command -Session $dcsessiondom -ScriptBlock { Import-Certificate -FilePath C:\intcert.cer -CertStoreLocation Cert:\LocalMachine\CA | out-null }
        Invoke-Command -Session $dcsessiondom -ScriptBlock { Get-ChildItem Cert:\LocalMachine\My | Remove-Item }
        Invoke-Command -Session $dcsessiondom -ScriptBlock { certreq -machine -q -enroll "Domain Controller Authentication (KDC)" | Out-Null }
        $dcsessiondom | Remove-PSSession
        Write-LogEntry -Message "PowerShell Direct session for $($CAConfig.domainuser.UserName) has been disconnected from $($cAconfig.name)" -Type Information
        Invoke-Pester -TestName "CA"
        Write-LogEntry -Message "Installation of CA Server named $($cAconfig.name) is completed" -Type Information
    }
}
