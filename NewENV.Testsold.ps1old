$scriptpath = $PSScriptRoot
$config = Get-Content "$scriptpath\env.json" -Raw | ConvertFrom-Json
$envConfig = $config.ENVConfig | Where-Object { $_.env -eq $config.env }
$admpwd = $envConfig.AdminPW
$localadmin = new-object -typename System.Management.Automation.PSCredential -argumentlist "administrator", (ConvertTo-SecureString -String $admpwd -AsPlainText -Force)
$domuser = new-object -typename System.Management.Automation.PSCredential -argumentlist "$($envconfig.env)\administrator", (ConvertTo-SecureString -String $admpwd -AsPlainText -Force)
$vmpath = $envConfig.VMPath
$swname = $envConfig.SwitchName
#$ipsub = $envConfig.ipsubnet
$DomainFQDN = $envconfig.DomainFQDN
#$RRASname = $Config.RRASname
$RefVHDX = $config.REFVHDX
#$dcname = "$($envconfig.env)`DC"
#if ($Config.SCCMCAS -eq "1") {
#    $cmconfig.name = "$($envconfig.ENV)`CMCAS"
#}
#else {
#    $cmconfig.name = "$($envconfig.env)`CM"
#}

. .\Lab.Classes.ps1
Describe "RRAS" -Tag ("Network", "RRAS", "VM") {
    $RRASConfig = [RRAS]::new()
    $rrasconfig.load("$(split-path $vmpath)\RRASConfig.json")
    $tRRASVHDXExists = test-path $RRASConfig.VHDXpath
    $tRRASExist = (get-vm -Name $RRASConfig.Name -ErrorAction SilentlyContinue).count
    $trrasrunning = (get-vm -Name $RRASConfig.Name -ErrorAction SilentlyContinue | Where-Object { $_.State -match "Running" }).Count
    if ($tRRASExist -eq 1 -and $trrasrunning -eq 1) {
        $trrasSession = New-PSSession -VMName $RRASConfig.Name -Credential $localadmin
        $rrasfeat = (Invoke-Command -Session $trrasSession -ScriptBlock { (get-windowsfeature -name routing).installstate }).value
        $rrasEXTrename = (Invoke-Command -Session $trrasSession -ScriptBlock { Get-NetAdapter -Physical -Name "External" -ErrorAction SilentlyContinue }).name
        $rrasLABrename = (Invoke-Command -Session $trrasSession -ScriptBlock { param($n)Get-NetAdapter -Physical -Name $n -ErrorAction SilentlyContinue } -ArgumentList $RRASConfig.network).name
        $rrasVPNStatus = (Invoke-Command -Session $trrasSession -ScriptBlock { if ((get-command Get-RemoteAccess -ErrorAction SilentlyContinue).count -eq 1) { Get-RemoteAccess -ErrorAction SilentlyContinue } })
        $rrasLabIPAddress = (Invoke-Command -Session $trrasSession -ScriptBlock { param($n)(Get-NetIPAddress -interfacealias $n -AddressFamily IPv4 -ErrorAction SilentlyContinue).ipaddress } -ArgumentList $RRASConfig.network)
        $tRRASInternet = (Invoke-Command -Session $trrasSession -ScriptBlock { test-netconnection "8.8.8.8" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue }).PingSucceeded
        $trrasSession | Remove-PSSession
    }
    it 'RRAS VHDX Should exist' { $tRRASVHDXExists | should be $true }
    it 'RRAS Server Should exist' { $tRRASExist | should be 1 }    
    it 'RRAS Server is Running' { $trrasrunning | should be 1 }
    it 'RRAS Routing Installed' -Skip:(!($tRRASExist -eq 1 -and $trrasrunning -eq 1)) { $rrasfeat | should be "Installed" }
    it 'RRAS External NIC Renamed' -Skip:(!($tRRASExist -eq 1 -and $trrasrunning -eq 1)) { $rrasEXTrename | should be "External" }
    it 'RRAS Lab NIC Renamed' -Skip:(!($tRRASExist -eq 1 -and $trrasrunning -eq 1)) { $rrasLABrename | should be $RRASConfig.network }
    it 'RRAS Lab IP Address Set' -Skip:(!($tRRASExist -eq 1 -and $trrasrunning -eq 1)) { $rrasLabIPAddress | should be $RRASConfig.ipaddress }
    it 'RRAS VPN enabled' -Skip:(!($tRRASExist -eq 1 -and $trrasrunning -eq 1)) { $rrasVPNStatus.VpnStatus | should be 'Installed' }
    it 'RRAS has access to Internet' -Skip:(!($tRRASExist -eq 1 -and $trrasrunning -eq 1)) { $tRRASInternet | should be $true }
}

Describe "DC" -Tag ("Domain", "VM") {
    $DCConfig = [DC]::new()
    $dcconfig.load("$vmpath\dcconfig.json")
    $TDCVHDXExists = (Test-Path -path $DCConfig.VHDXpath)
    $TDCExists = (get-vm -name $dcconfig.Name -ErrorAction SilentlyContinue).count
    $TDCRunning = (get-vm -name $dcconfig.Name -ErrorAction SilentlyContinue | Where-Object { $_.State -match "Running" }).count
    if ($TDCExists -eq 1 -and $TDCRunning -eq 1) {
        $TDCSession = new-PSSession -VMName $dcconfig.Name -Credential $localadmin -ErrorAction SilentlyContinue
        if (!($TDCSession)) { $TDCSession = new-PSSession -VMName $dcconfig.Name -Credential $domuser; $TDCPromoted = $true } else { $TDCPromoted = $false }
        $TDCIPAddress = (Invoke-Command -Session $TDCSession -ScriptBlock { (Get-NetIPAddress -AddressFamily IPv4 -PrefixOrigin Manual -ErrorAction SilentlyContinue).ipaddress })
        $TDCFeat = (Invoke-Command -Session $TDCSession -ScriptBlock { (get-windowsfeature -name AD-Domain-Services).installstate }).value
        $TDCTestInternet = (Invoke-Command -Session $TDCSession -ScriptBlock { test-netconnection "steven.hosking.com.au" -CommonTCPPort HTTP -WarningAction SilentlyContinue -ErrorAction SilentlyContinue }).TcpTestSucceeded
        $TDCPromoted = (Invoke-Command -Session $TDCSession -ScriptBlock { Get-Service -Name "NTDS" -ErrorAction SilentlyContinue }).status
        $TDCDHCPScopeexists = (Invoke-Command -Session $TDCSession -ScriptBlock { if (get-command Get-DhcpServerv4Scope -ErrorAction SilentlyContinue) { Get-DhcpServerv4Scope -ErrorAction SilentlyContinue -warningaction SilentlyContinue } })
        $TDCADWSState = (Invoke-Command -session $TDCSession { Get-WmiObject -class Win32_Service -filter 'name="adws"' }).state
        if ($TDCADWSState -eq "Running")
        { $TDCSCCMGroupExists = (Invoke-Command -Session $TDCSession -ScriptBlock { if (get-command get-adgroup -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) { get-adgroup -Filter "name -eq 'SCCM Servers'" -ErrorAction SilentlyContinue -WarningAction SilentlyContinue } }) }
        $TDCSession | Remove-PSSession
    }
    it 'DC VHDX Should Exist' { $TDCVHDXExists | should be $true }
    it "DC Should Exist" { $TDCExists | should be 1 }
    it "DC Should be running" { $TDCRunning | should be 1 }
    it 'DC IP Address' -Skip:(!($TDCExists -eq 1 -and $TDCRunning -eq 1)) { $TDCIPAddress | should be $DCConfig.IPAddress }
    it 'DC has access to Internet' -Skip:(!($TDCExists -eq 1 -and $TDCRunning -eq 1)) { $TDCTestInternet | should be $true }
    it 'DC Domain Services Installed' -Skip:(!($TDCExists -eq 1 -and $TDCRunning -eq 1)) { $TDCFeat | should be "Installed" }
    it 'DC Promoted' -Skip:(!($TDCExists -eq 1 -and $TDCRunning -eq 1)) { $TDCPromoted | should be "Running" }
    it 'DC DHCP Scope Active' -Skip:(!($TDCExists -eq 1 -and $TDCRunning -eq 1)) { $TDCDHCPScopeexists[0].State | should be "Active" }
    it 'DC SCCM Servers Group' -Skip:(!($TDCExists -eq 1 -and $TDCRunning -eq 1)) { $TDCSCCMGroupExists[0].name | should be "SCCM Servers" }
}

if ($Config.SCCMENVType -eq "CAS") {
    Describe "CMCAS" -tag ("CAS") {
        $CMConfig = [CM]::new()
        $CMConfig.load("$vmpath\$($config.env)`cmCASconfig.json")
        $TCMVHDXExists = (Test-Path -path $CMConfig.VHDXpath)
        $TCMExists = (get-vm -name $cmconfig.name -ErrorAction SilentlyContinue).count
        $TCMRunning = (get-vm -name $cmconfig.name -ErrorAction SilentlyContinue | Where-Object { $_.State -match "Running" }).count
        if ($TCMExists -eq 1 -and $TCMRunning -eq 1) {
            $TCMSession = new-PSSession -VMName $cmconfig.name -Credential $localadmin -ErrorAction SilentlyContinue
            if (!($TCMSession)) { $TCMSession = new-PSSession -VMName $cmconfig.name -Credential $domuser }
            $TCMIPAddress = (Invoke-Command -Session $TCMSession -ScriptBlock { (Get-NetIPAddress -AddressFamily IPv4 -PrefixOrigin Manual -ErrorAction SilentlyContinue).ipaddress })
            $TCMTestInternet = (Invoke-Command -Session $TCMSession -ScriptBlock { test-netconnection "8.8.8.8" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue }).PingSucceeded
            $TCMTestDomain = (Invoke-Command -Session $TCMSession -ScriptBlock { param($d)Test-NetConnection $d -erroraction SilentlyContinue -WarningAction SilentlyContinue } -ArgumentList $CMConfig.domainFQDN ).PingSucceeded
            $TCMFeat = (Invoke-Command -Session $TCMSession -ScriptBlock { (get-windowsfeature -name BITS, BITS-IIS-Ext, BITS-Compact-Server, Web-Server, Web-WebServer, Web-Common-Http, Web-Default-Doc, Web-Dir-Browsing, Web-Http-Errors, Web-Static-Content, Web-Http-Redirect, Web-App-Dev, Web-Net-Ext, Web-Net-Ext45, Web-ASP, Web-Asp-Net, Web-Asp-Net45, Web-CGI, Web-ISAPI-Ext, Web-ISAPI-Filter, Web-Health, Web-Http-Logging, Web-Custom-Logging, Web-Log-Libraries, Web-Request-Monitor, Web-Http-Tracing, Web-Performance, Web-Stat-Compression, Web-Security, Web-Filtering, Web-Basic-Auth, Web-IP-Security, Web-Url-Auth, Web-Windows-Auth, Web-Mgmt-Tools, Web-Mgmt-Console, Web-Mgmt-Compat, Web-Metabase, Web-Lgcy-Mgmt-Console, Web-Lgcy-Scripting, Web-WMI, Web-Scripting-Tools, Web-Mgmt-Service, RDC) | Where-Object { $_.installstate -eq "Installed" } }).count
            $TCMNetFeat = (Invoke-Command -Session $TCMSession -ScriptBlock { (get-windowsfeature -name NET-Framework-Features, NET-Framework-Core) | Where-Object { $_.installstate -eq "Installed" } }).count
            $TCMSQLInstalled = (Invoke-Command -Session $TCMSession -ScriptBlock { get-service -name "MSSQLSERVER" -ErrorAction SilentlyContinue }).name.count
            $TCMADKInstalled = (Invoke-Command -Session $TCMSession -ScriptBlock { test-path "C:\Program Files (x86)\Windows Kits\10\Assessment and deployment kit" -ErrorAction SilentlyContinue })
            $TCMSCCMServerinGRP = (Invoke-Command -Session $TCMSession -ScriptBlock { Get-ADGroupMember "SCCM Servers" | Where-Object { $_.name -eq $env:computername } } -ErrorAction SilentlyContinue).name.count
            $TCMSCCMInstalled = (Invoke-Command -Session $TCMSession -ScriptBlock { get-service -name "SMS_EXECUTIVE" -ErrorAction SilentlyContinue }).name.count
            $TCMSCCMConsoleInstalled = (Invoke-Command -Session $TCMSession -ScriptBlock { test-path "C:\Program Files (x86)\Microsoft Configuration Manager\AdminConsole\bin\Microsoft.ConfigurationManagement.exe" })
            if ($TCMSCCMConsoleInstalled) {
                Invoke-Command -Session $TCMSession -ScriptBlock { param ($sitecode) import-module "$(($env:SMS_ADMIN_UI_PATH).remove(($env:SMS_ADMIN_UI_PATH).Length -4, 4))ConfigurationManager.psd1"; if ($null -eq (Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) { New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $env:COMPUTERNAME }; Set-Location "$((Get-PSDrive -PSProvider CMSite).name)`:" } -ArgumentList $CMConfig.cmsitecode
                $TCMBoundary = (Invoke-Command -Session $TCMSession -ScriptBlock { param($subname) Get-CMBoundary -name $subname } -ArgumentList $CMConfig.network).displayname.count
                $TCMDiscovery = (Invoke-Command -Session $TCMSession -ScriptBlock { Get-CMDiscoveryMethod -Name ActiveDirectorySystemDiscovery }).flag
            }
            $TCMSession | Remove-PSSession
        }
        it 'CM VHDX Should Exist' { $TCMVHDXExists | should be $true }
        it 'CM Should Exist' { $TCMExists | should be 1 }
        it 'CM Should be running' { $TCMRunning | should be 1 }
        it 'CM IP Address' -Skip:(!($TCMExists -eq 1 -and $TCMRunning -eq 1)) { $TCMIPAddress | should be $CMConfig.IPAddress }
        it 'CM has access to Internet' -Skip:(!($TCMExists -eq 1 -and $TCMRunning -eq 1)) { $TCMTestInternet | should be $true }
        it "CM has access to $DomainFQDN" -Skip:(!($TCMExists -eq 1 -and $TCMRunning -eq 1)) { $TCMTestDomain | Should be $true }
        it 'CM .Net Feature installed' -Skip:(!($TCMExists -eq 1 -and $TCMRunning -eq 1)) { $TCMNetFeat | should be 2 }
        it 'CM Features are installed' -Skip:(!($TCMExists -eq 1 -and $TCMRunning -eq 1)) { $TCMFeat | should be 44 }
        it 'CM SQL Instance is installed' -Skip:(!($TCMExists -eq 1 -and $TCMRunning -eq 1)) { $TCMSQLInstalled | should be 1 }
        it 'CM ADK Installed' -Skip:(!($TCMExists -eq 1 -and $TCMRunning -eq 1)) { $TCMADKInstalled | should be $true }
        it 'CM Server in Group' -Skip:(!($TCMExists -eq 1 -and $TCMRunning -eq 1)) { $TCMSCCMServerinGRP | should be 1 }
        it 'CM SCCM Installed' -Skip:(!($TCMExists -eq 1 -and $TCMRunning -eq 1)) { $TCMSCCMInstalled | should be 1 }
        it 'CM SCCM Console Installed' -Skip:(!($TCMExists -eq 1 -and $TCMRunning -eq 1)) { $TCMSCCMConsoleInstalled | should be $true }
        it 'CM Site Boundary added' -Skip:(!($TCMExists -eq 1 -and $TCMRunning -eq 1 -and $TCMSCCMConsoleInstalled)) { $TCMBoundary | should be 1 }
        it 'CM System Discovery enabled' -Skip:(!($TCMExists -eq 1 -and $TCMRunning -eq 1 -and $TCMSCCMConsoleInstalled)) { $TCMDiscovery | should be 6 }
    }
    Describe "CMCAS" -tag ("CASPRI") {
        $CMConfig = [CM]::new()
        $CMConfig.load("$vmpath\$($config.env)`cmCASPRIconfig.json")
        $TCMVHDXExists = (Test-Path -path $CMConfig.VHDXpath)
        $TCMExists = (get-vm -name $cmconfig.name -ErrorAction SilentlyContinue).count
        $TCMRunning = (get-vm -name $cmconfig.name -ErrorAction SilentlyContinue | Where-Object { $_.State -match "Running" }).count
        if ($TCMExists -eq 1 -and $TCMRunning -eq 1) {
            $TCMSession = new-PSSession -VMName $cmconfig.name -Credential $localadmin -ErrorAction SilentlyContinue
            if (!($TCMSession)) { $TCMSession = new-PSSession -VMName $cmconfig.name -Credential $domuser }
            $TCMIPAddress = (Invoke-Command -Session $TCMSession -ScriptBlock { (Get-NetIPAddress -AddressFamily IPv4 -PrefixOrigin Manual -ErrorAction SilentlyContinue).ipaddress })
            $TCMTestInternet = (Invoke-Command -Session $TCMSession -ScriptBlock { test-netconnection "8.8.8.8" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue }).PingSucceeded
            $TCMTestDomain = (Invoke-Command -Session $TCMSession -ScriptBlock { param($d)Test-NetConnection $d -erroraction SilentlyContinue -WarningAction SilentlyContinue } -ArgumentList $CMConfig.domainFQDN ).PingSucceeded
            $TCMFeat = (Invoke-Command -Session $TCMSession -ScriptBlock { (get-windowsfeature -name BITS, BITS-IIS-Ext, BITS-Compact-Server, Web-Server, Web-WebServer, Web-Common-Http, Web-Default-Doc, Web-Dir-Browsing, Web-Http-Errors, Web-Static-Content, Web-Http-Redirect, Web-App-Dev, Web-Net-Ext, Web-Net-Ext45, Web-ASP, Web-Asp-Net, Web-Asp-Net45, Web-CGI, Web-ISAPI-Ext, Web-ISAPI-Filter, Web-Health, Web-Http-Logging, Web-Custom-Logging, Web-Log-Libraries, Web-Request-Monitor, Web-Http-Tracing, Web-Performance, Web-Stat-Compression, Web-Security, Web-Filtering, Web-Basic-Auth, Web-IP-Security, Web-Url-Auth, Web-Windows-Auth, Web-Mgmt-Tools, Web-Mgmt-Console, Web-Mgmt-Compat, Web-Metabase, Web-Lgcy-Mgmt-Console, Web-Lgcy-Scripting, Web-WMI, Web-Scripting-Tools, Web-Mgmt-Service, RDC) | Where-Object { $_.installstate -eq "Installed" } }).count
            $TCMNetFeat = (Invoke-Command -Session $TCMSession -ScriptBlock { (get-windowsfeature -name NET-Framework-Features, NET-Framework-Core) | Where-Object { $_.installstate -eq "Installed" } }).count
            $TCMSQLInstalled = (Invoke-Command -Session $TCMSession -ScriptBlock { get-service -name "MSSQLSERVER" -ErrorAction SilentlyContinue }).name.count
            $TCMADKInstalled = (Invoke-Command -Session $TCMSession -ScriptBlock { test-path "C:\Program Files (x86)\Windows Kits\10\Assessment and deployment kit" -ErrorAction SilentlyContinue })
            $TCMSCCMServerinGRP = (Invoke-Command -Session $TCMSession -ScriptBlock { Get-ADGroupMember "SCCM Servers" | Where-Object { $_.name -eq $env:computername } } -ErrorAction SilentlyContinue).name.count
            $TCMSCCMInstalled = (Invoke-Command -Session $TCMSession -ScriptBlock { get-service -name "SMS_EXECUTIVE" -ErrorAction SilentlyContinue }).name.count
            $TCMSCCMConsoleInstalled = (Invoke-Command -Session $TCMSession -ScriptBlock { test-path "C:\Program Files (x86)\Microsoft Configuration Manager\AdminConsole\bin\Microsoft.ConfigurationManagement.exe" })
            if ($TCMSCCMConsoleInstalled) {
                Invoke-Command -Session $TCMSession -ScriptBlock { param ($sitecode) import-module "$(($env:SMS_ADMIN_UI_PATH).remove(($env:SMS_ADMIN_UI_PATH).Length -4, 4))ConfigurationManager.psd1"; if ($null -eq (Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) { New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $env:COMPUTERNAME }; Set-Location "$((Get-PSDrive -PSProvider CMSite).name)`:" } -ArgumentList $CMConfig.cmsitecode
                $TCMBoundary = (Invoke-Command -Session $TCMSession -ScriptBlock { param($subname) Get-CMBoundary -name $subname } -ArgumentList $CMConfig.network).displayname.count
                $TCMDiscovery = (Invoke-Command -Session $TCMSession -ScriptBlock { Get-CMDiscoveryMethod -Name ActiveDirectorySystemDiscovery }).flag
            }
            $TCMSession | Remove-PSSession
        }
        it 'CM VHDX Should Exist' { $TCMVHDXExists | should be $true }
        it 'CM Should Exist' { $TCMExists | should be 1 }
        it 'CM Should be running' { $TCMRunning | should be 1 }
        it 'CM IP Address' -Skip:(!($TCMExists -eq 1 -and $TCMRunning -eq 1)) { $TCMIPAddress | should be $CMConfig.IPAddress }
        it 'CM has access to Internet' -Skip:(!($TCMExists -eq 1 -and $TCMRunning -eq 1)) { $TCMTestInternet | should be $true }
        it "CM has access to $DomainFQDN" -Skip:(!($TCMExists -eq 1 -and $TCMRunning -eq 1)) { $TCMTestDomain | Should be $true }
        it 'CM .Net Feature installed' -Skip:(!($TCMExists -eq 1 -and $TCMRunning -eq 1)) { $TCMNetFeat | should be 2 }
        it 'CM Features are installed' -Skip:(!($TCMExists -eq 1 -and $TCMRunning -eq 1)) { $TCMFeat | should be 44 }
        it 'CM SQL Instance is installed' -Skip:(!($TCMExists -eq 1 -and $TCMRunning -eq 1)) { $TCMSQLInstalled | should be 1 }
        it 'CM ADK Installed' -Skip:(!($TCMExists -eq 1 -and $TCMRunning -eq 1)) { $TCMADKInstalled | should be $true }
        it 'CM Server in Group' -Skip:(!($TCMExists -eq 1 -and $TCMRunning -eq 1)) { $TCMSCCMServerinGRP | should be 1 }
        it 'CM SCCM Installed' -Skip:(!($TCMExists -eq 1 -and $TCMRunning -eq 1)) { $TCMSCCMInstalled | should be 1 }
        it 'CM SCCM Console Installed' -Skip:(!($TCMExists -eq 1 -and $TCMRunning -eq 1)) { $TCMSCCMConsoleInstalled | should be $true }
        it 'CM Site Boundary added' -Skip:(!($TCMExists -eq 1 -and $TCMRunning -eq 1 -and $TCMSCCMConsoleInstalled)) { $TCMBoundary | should be 1 }
        it 'CM System Discovery enabled' -Skip:(!($TCMExists -eq 1 -and $TCMRunning -eq 1 -and $TCMSCCMConsoleInstalled)) { $TCMDiscovery | should be 6 }
    }
}
else {
    Describe "CM" -tag ("PRI") {
        $CMConfig = [CM]::new()
        $CMConfig.load("$vmpath\$($config.env)`cmconfig.json")
        $TCMVHDXExists = (Test-Path -path $CMConfig.VHDXpath)
        $TCMExists = (get-vm -name $cmconfig.name -ErrorAction SilentlyContinue).count
        $TCMRunning = (get-vm -name $cmconfig.name -ErrorAction SilentlyContinue | Where-Object { $_.State -match "Running" }).count
        if ($TCMExists -eq 1 -and $TCMRunning -eq 1) {
            $TCMSession = new-PSSession -VMName $cmconfig.name -Credential $localadmin -ErrorAction SilentlyContinue
            if (!($TCMSession)) { $TCMSession = new-PSSession -VMName $cmconfig.name -Credential $domuser }
            $TCMIPAddress = (Invoke-Command -Session $TCMSession -ScriptBlock { (Get-NetIPAddress -AddressFamily IPv4 -PrefixOrigin Manual -ErrorAction SilentlyContinue).ipaddress })
            $TCMTestInternet = (Invoke-Command -Session $TCMSession -ScriptBlock { test-netconnection "8.8.8.8" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue }).PingSucceeded
            $TCMTestDomain = (Invoke-Command -Session $TCMSession -ScriptBlock { param($d)Test-NetConnection $d -erroraction SilentlyContinue -WarningAction SilentlyContinue } -ArgumentList $CMConfig.domainFQDN ).PingSucceeded
            $TCMFeat = (Invoke-Command -Session $TCMSession -ScriptBlock { (get-windowsfeature -name BITS, BITS-IIS-Ext, BITS-Compact-Server, Web-Server, Web-WebServer, Web-Common-Http, Web-Default-Doc, Web-Dir-Browsing, Web-Http-Errors, Web-Static-Content, Web-Http-Redirect, Web-App-Dev, Web-Net-Ext, Web-Net-Ext45, Web-ASP, Web-Asp-Net, Web-Asp-Net45, Web-CGI, Web-ISAPI-Ext, Web-ISAPI-Filter, Web-Health, Web-Http-Logging, Web-Custom-Logging, Web-Log-Libraries, Web-Request-Monitor, Web-Http-Tracing, Web-Performance, Web-Stat-Compression, Web-Security, Web-Filtering, Web-Basic-Auth, Web-IP-Security, Web-Url-Auth, Web-Windows-Auth, Web-Mgmt-Tools, Web-Mgmt-Console, Web-Mgmt-Compat, Web-Metabase, Web-Lgcy-Mgmt-Console, Web-Lgcy-Scripting, Web-WMI, Web-Scripting-Tools, Web-Mgmt-Service, RDC) | Where-Object { $_.installstate -eq "Installed" } }).count
            $TCMNetFeat = (Invoke-Command -Session $TCMSession -ScriptBlock { (get-windowsfeature -name NET-Framework-Features, NET-Framework-Core) | Where-Object { $_.installstate -eq "Installed" } }).count
            $TCMSQLInstalled = (Invoke-Command -Session $TCMSession -ScriptBlock { get-service -name "MSSQLSERVER" -ErrorAction SilentlyContinue }).name.count
            $TCMADKInstalled = (Invoke-Command -Session $TCMSession -ScriptBlock { test-path "C:\Program Files (x86)\Windows Kits\10\Assessment and deployment kit" -ErrorAction SilentlyContinue })
            $TCMSCCMServerinGRP = (Invoke-Command -Session $TCMSession -ScriptBlock { Get-ADGroupMember "SCCM Servers" | Where-Object { $_.name -eq $env:computername } } -ErrorAction SilentlyContinue).name.count
            $TCMSCCMInstalled = (Invoke-Command -Session $TCMSession -ScriptBlock { get-service -name "SMS_EXECUTIVE" -ErrorAction SilentlyContinue }).name.count
            $TCMSCCMConsoleInstalled = (Invoke-Command -Session $TCMSession -ScriptBlock { test-path "C:\Program Files (x86)\Microsoft Configuration Manager\AdminConsole\bin\Microsoft.ConfigurationManagement.exe" })
            if ($TCMSCCMConsoleInstalled) {
                Invoke-Command -Session $TCMSession -ScriptBlock { param ($sitecode) import-module "$(($env:SMS_ADMIN_UI_PATH).remove(($env:SMS_ADMIN_UI_PATH).Length -4, 4))ConfigurationManager.psd1"; if ($null -eq (Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) { New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $env:COMPUTERNAME }; Set-Location "$((Get-PSDrive -PSProvider CMSite).name)`:" } -ArgumentList $CMConfig.cmsitecode
                $TCMBoundary = (Invoke-Command -Session $TCMSession -ScriptBlock { param($subname) Get-CMBoundary -name $subname } -ArgumentList $CMConfig.network).displayname.count
                $TCMDiscovery = (Invoke-Command -Session $TCMSession -ScriptBlock { Get-CMDiscoveryMethod -Name ActiveDirectorySystemDiscovery }).flag
            }
            $TCMSession | Remove-PSSession
        }
        it 'CM VHDX Should Exist' { $TCMVHDXExists | should be $true }
        it 'CM Should Exist' { $TCMExists | should be 1 }
        it 'CM Should be running' { $TCMRunning | should be 1 }
        it 'CM IP Address' -Skip:(!($TCMExists -eq 1 -and $TCMRunning -eq 1)) { $TCMIPAddress | should be $CMConfig.IPAddress }
        it 'CM has access to Internet' -Skip:(!($TCMExists -eq 1 -and $TCMRunning -eq 1)) { $TCMTestInternet | should be $true }
        it "CM has access to $DomainFQDN" -Skip:(!($TCMExists -eq 1 -and $TCMRunning -eq 1)) { $TCMTestDomain | Should be $true }
        it 'CM .Net Feature installed' -Skip:(!($TCMExists -eq 1 -and $TCMRunning -eq 1)) { $TCMNetFeat | should be 2 }
        it 'CM Features are installed' -Skip:(!($TCMExists -eq 1 -and $TCMRunning -eq 1)) { $TCMFeat | should be 44 }
        it 'CM SQL Instance is installed' -Skip:(!($TCMExists -eq 1 -and $TCMRunning -eq 1)) { $TCMSQLInstalled | should be 1 }
        it 'CM ADK Installed' -Skip:(!($TCMExists -eq 1 -and $TCMRunning -eq 1)) { $TCMADKInstalled | should be $true }
        it 'CM Server in Group' -Skip:(!($TCMExists -eq 1 -and $TCMRunning -eq 1)) { $TCMSCCMServerinGRP | should be 1 }
        it 'CM SCCM Installed' -Skip:(!($TCMExists -eq 1 -and $TCMRunning -eq 1)) { $TCMSCCMInstalled | should be 1 }
        it 'CM SCCM Console Installed' -Skip:(!($TCMExists -eq 1 -and $TCMRunning -eq 1)) { $TCMSCCMConsoleInstalled | should be $true }
        it 'CM Site Boundary added' -Skip:(!($TCMExists -eq 1 -and $TCMRunning -eq 1 -and $TCMSCCMConsoleInstalled)) { $TCMBoundary | should be 1 }
        it 'CM System Discovery enabled' -Skip:(!($TCMExists -eq 1 -and $TCMRunning -eq 1 -and $TCMSCCMConsoleInstalled)) { $TCMDiscovery | should be 6 }
    }
}


Describe "CA" -tag ("CA", "VM") {
    $CAConfig = [CA]::new()
    $CAConfig.load("$VMpath\CAconfig.json")
    $TCAVHDXExists = (Test-Path -path $CAConfig.VHDXpath)
    $TCAExists = (get-vm -name $CAConfig.Name -ErrorAction SilentlyContinue).count
    $TCARunning = (get-vm -name $CAConfig.Name -ErrorAction SilentlyContinue | Where-Object { $_.State -match "Running" }).count
    if ($TCAExists -eq 1 -and $TCARunning -eq 1) {
        $TCASession = new-PSSession -VMName $CAConfig.Name -Credential $localadmin -ErrorAction SilentlyContinue
        if (!($TCASession)) { $TCASession = new-PSSession -VMName $CAConfig.Name -Credential $domuser }
        $TCAIPAddress = (Invoke-Command -Session $TCASession -ScriptBlock { (Get-NetIPAddress -AddressFamily IPv4 -PrefixOrigin Manual -ErrorAction SilentlyContinue).ipaddress })
        $TCATestInternet = (Invoke-Command -Session $TCASession -ScriptBlock { test-netconnection "8.8.8.8" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue }).PingSucceeded
        $TCATestDomain = (Invoke-Command -Session $TCASession -ScriptBlock { param($d)Test-NetConnection $d -erroraction SilentlyContinue -WarningAction SilentlyContinue } -ArgumentList $CAConfig.domainFQDN ).PingSucceeded
        $TCAFeat = (Invoke-Command -Session $TCASession -ScriptBlock { (get-windowsfeature -name Adcs-Cert-Authority | Where-Object { $_.installstate -eq "Installed" }).count })
        $TCASession | Remove-PSSession
    }
    it 'CA VHDX Should Exist' { $TCAVHDXExists | should be $true }
    it 'CA Should Exist' { $TCAExists | should be 1 }
    it 'CA Should be running' { $TCARunning | should be 1 }
    it 'CA IP Address' -Skip:(!($TCAExists -eq 1 -and $TCARunning -eq 1)) { $TCAIPAddress | should be $CAConfig.IPAddress }
    it 'CA has access to Internet' -Skip:(!($TCAExists -eq 1 -and $TCARunning -eq 1)) { $TCATestInternet | should be $true }
    it "CA has access to $DomainFQDN" -Skip:(!($TCAExists -eq 1 -and $TCARunning -eq 1)) { $TCATestDomain | Should be $true }
    it 'CA Feature is installed' -Skip:(!($TCAExists -eq 1 -and $TCARunning -eq 1)) { $TCAFeat | should be 1 }

}

Describe "vSwitch" -tag ("Network", "ENV") {
    $lresult = (Get-VMSwitch -Name $swname -ErrorAction SilentlyContinue).count
    $Iresult = (Get-VMSwitch -Name "Internet" -ErrorAction SilentlyContinue).count
    it "Lab VMSwitch Should exist" { $lresult | should be 1 }
    it 'Internet VSwitch should exist' { $Iresult | should be 1 }
}

Describe "Reference-VHDX" -Tag ("VM", "Template") {
    $result = (Test-Path -Path "$RefVHDX")
    it 'VHDX Should exist' { $result | should be $true }
}

Describe "Test Source Media" -tag ("VM", "ENV") {
    $Win16iso = (Test-path -Path "$($config.WIN16ISO)")
    $SQLMedia = (Test-Path -Path "$($config.SQLISO)")
    $adkmedia = (Test-Path -Path "$($config.ADKPATH)")
    $SCCMMedia = (Test-Path -Path "$($config.SCCMPath)")
    $SCCMDLMedia = (Test-Path -Path "$($config.SCCMPath)\DL")
    $net35path = (Test-Path -Path "$($config.WINNET35CAB)")
    $unattendpath = $config.REFVHDX -replace ($config.REFVHDX.split('\') | Select-Object -last 1), "Unattended.xml" ## is wrong, need to change to correct path
    $win16unattend = (test-path "$($unattendpath)")
    it 'Windows 2016 source media' { $Win16iso | should be $true }
    it 'Windows 2016 Unattend' { $win16unattend | should be $true }
    it 'SQL 2016 Media' { $SQLMedia | Should be $true }
    it 'ADK Content' { $adkmedia | should be $true }
    it 'SCCM Media' { $SCCMMedia | should be $true }
    it 'SCCM Download Media' { $SCCMDLMedia | should be $true }
    it '.net 3.5 Media' { $net35path | should be $true }
}