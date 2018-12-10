$scriptpath = $PSScriptRoot
$config = Get-Content "$scriptpath\env.json" -Raw | ConvertFrom-Json
$envConfig = $config.ENVConfig | Where-Object {$_.env -eq $config.env}
$admpwd = $envConfig.AdminPW
$localadmin = new-object -typename System.Management.Automation.PSCredential -argumentlist "administrator", (ConvertTo-SecureString -String $admpwd -AsPlainText -Force)
$domuser = new-object -typename System.Management.Automation.PSCredential -argumentlist "$($envconfig.env)\administrator", (ConvertTo-SecureString -String $admpwd -AsPlainText -Force)
$vmpath = $envConfig.VMPath
$swname = $envConfig.SwitchName
$ipsub = $envConfig.ipsubnet
$DomainFQDN = $envconfig.DomainFQDN
$RRASname = $Config.RRASname
$RefVHDX = $config.REFVHDX
$dcname = "$($envconfig.env)`DC"
$CMname = "$($envconfig.env)`CM"
$CAname = "$($envconfig.env)`CA"
Describe "RRAS" -Tag ("Network", "RRAS", "VM") {
    $tRRASVHDXExists = (get-childitem -Path "$(split-path $vmpath)" -filter "$($RRASname)c.vhdx")
    $tRRASExist = (get-vm -Name $RRASname -ErrorAction SilentlyContinue).count
    $trrasrunning = (get-vm -Name $RRASname -ErrorAction SilentlyContinue | Where-Object {$_.State -match "Running"}).Count
    if ($tRRASExist -eq 1 -and $trrasrunning -eq 1) {
        $trrasSession = New-PSSession -VMName $RRASname -Credential $localadmin
        $rrasfeat = (Invoke-Command -Session $trrasSession -ScriptBlock {(get-windowsfeature -name routing).installstate}).value
        $rrasEXTrename = (Invoke-Command -Session $trrasSession -ScriptBlock {Get-NetAdapter -Physical -Name "External" -ErrorAction SilentlyContinue}).name
        $rrasLABrename = (Invoke-Command -Session $trrasSession -ScriptBlock {param($n)Get-NetAdapter -Physical -Name $n -ErrorAction SilentlyContinue} -ArgumentList $config.env).name
        $rrasVPNStatus = (Invoke-Command -Session $trrasSession -ScriptBlock {if((get-command Get-RemoteAccess -ErrorAction SilentlyContinue).count -eq 1) {Get-RemoteAccess -ErrorAction SilentlyContinue}})
        $rrasLabIPAddress = (Invoke-Command -Session $trrasSession -ScriptBlock {param($n)(Get-NetIPAddress -interfacealias $n -AddressFamily IPv4 -ErrorAction SilentlyContinue).ipaddress} -ArgumentList $config.env)
        $tRRASInternet = (Invoke-Command -Session $trrasSession -ScriptBlock {test-netconnection "8.8.8.8" -WarningAction SilentlyContinue}).PingSucceeded
        $trrasSession | Remove-PSSession
    }
    it 'RRAS VHDX Should exist' {$tRRASVHDXExists | should be $true}
    it 'RRAS Server Should exist' {$tRRASExist | should be 1}    
    it 'RRAS Server is Running' {$trrasrunning | should be 1}
    it 'RRAS Routing Installed' -Skip:(!($tRRASExist -eq 1 -and $trrasrunning -eq 1)) {$rrasfeat | should be "Installed"}
    it 'RRAS External NIC Renamed' -Skip:(!($tRRASExist -eq 1 -and $trrasrunning -eq 1)) {$rrasEXTrename | should be "External"}
    it 'RRAS Lab NIC Renamed' -Skip:(!($tRRASExist -eq 1 -and $trrasrunning -eq 1)) {$rrasLABrename | should be $config.ENV}
    it 'RRAS Lab IP Address Set' -Skip:(!($tRRASExist -eq 1 -and $trrasrunning -eq 1)) {$rrasLabIPAddress | should be "$ipsub`1"}
    it 'RRAS VPN enabled' -Skip:(!($tRRASExist -eq 1 -and $trrasrunning -eq 1)) {$rrasVPNStatus.VpnStatus | should be 'Installed'}
    it 'RRAS has access to Internet' -Skip:(!($tRRASExist -eq 1 -and $trrasrunning -eq 1)) {$tRRASInternet | should be $true}
}

Describe "DC" -Tag ("Domain", "VM") {
    $TDCVHDXExists = (Test-Path -path "$vmpath\$($dcname)c.vhdx")
    $TDCExists = (get-vm -name $DCName -ErrorAction SilentlyContinue).count
    $TDCRunning = (get-vm -name $DCName -ErrorAction SilentlyContinue | Where-Object {$_.State -match "Running"}).count
    if ($TDCExists -eq 1 -and $TDCRunning -eq 1) {
        $TDCSession = new-PSSession -VMName $dcname -Credential $localadmin -ErrorAction SilentlyContinue
        if(!($TDCSession)) {$TDCSession = new-PSSession -VMName $dcname -Credential $domuser; $TDCPromoted = $true} else {$TDCPromoted = $false}
        $TDCIPAddress = (Invoke-Command -Session $TDCSession -ScriptBlock {(Get-NetIPAddress -AddressFamily IPv4 -PrefixOrigin Manual -ErrorAction SilentlyContinue).ipaddress})
        $TDCFeat = (Invoke-Command -Session $TDCSession -ScriptBlock {(get-windowsfeature -name AD-Domain-Services).installstate}).value
        $TDCTestInternet = (Invoke-Command -Session $TDCSession -ScriptBlock {test-netconnection "steven.hosking.com.au" -CommonTCPPort HTTP -WarningAction SilentlyContinue}).TcpTestSucceeded
        $TDCPromoted = (Invoke-Command -Session $TDCSession -ScriptBlock {Get-Service -Name "NTDS" -ErrorAction SilentlyContinue}).status
        $TDCDHCPScopeexists = (Invoke-Command -Session $TDCSession -ScriptBlock {Get-DhcpServerv4Scope})
        $TDCSession | Remove-PSSession
    }
    it 'DC VHDX Should Exist' {$TDCVHDXExists | should be $true}
    it "DC Should Exist" {$TDCExists | should be 1}
    it "DC Should be running" {$TDCRunning | should be 1}
    it 'DC IP Address' -Skip:(!($TDCExists -eq 1 -and $TDCRunning -eq 1)) {$TDCIPAddress | should be "$ipsub`10"}
    it 'DC has access to Internet' -Skip:(!($TDCExists -eq 1 -and $TDCRunning -eq 1)) {$TDCTestInternet | should be $true}
    it 'DC Domain Services Installed' -Skip:(!($TDCExists -eq 1 -and $TDCRunning -eq 1)) {$TDCFeat | should be "Installed"}
    it 'DC Promoted' -Skip:(!($TDCExists -eq 1 -and $TDCRunning -eq 1)) {$TDCPromoted | should be "Running"}
    it "DC DHCP Scope Active" -Skip:(!($TDCExists -eq 1 -and $TDCRunning -eq 1)) {$TDCDHCPScopeexists[0].State | should be "Active"}
}

Describe "CM" -tag ("ConfigMgr","VM") {
    $TCMVHDXExists = (Test-Path -path "$vmpath\$($CMname)c.vhdx")
    $TCMExists = (get-vm -name $CMname -ErrorAction SilentlyContinue).count
    $TCMRunning = (get-vm -name $CMname -ErrorAction SilentlyContinue | Where-Object {$_.State -match "Running"}).count
    if ($TCMExists -eq 1 -and $TCMRunning -eq 1) {
        $TCMSession = new-PSSession -VMName $CMname -Credential $localadmin -ErrorAction SilentlyContinue
        if(!($TCMSession)) {$TCMSession = new-PSSession -VMName $CMname -Credential $domuser}
        $TCMIPAddress = (Invoke-Command -Session $TCMSession -ScriptBlock {(Get-NetIPAddress -AddressFamily IPv4 -PrefixOrigin Manual -ErrorAction SilentlyContinue).ipaddress})
        $TCMTestInternet = (Invoke-Command -Session $TCMSession -ScriptBlock {test-netconnection "8.8.8.8" -WarningAction SilentlyContinue}).PingSucceeded
        $TCMTestDomain = (Invoke-Command -Session $TCMSession -ScriptBlock {param($d)Test-NetConnection $d -erroraction SilentlyContinue -WarningAction SilentlyContinue} -ArgumentList $DomainFQDN ).PingSucceeded
        $TCMFeat = (Invoke-Command -Session $TCMSession -ScriptBlock {(get-windowsfeature -name BITS, BITS-IIS-Ext, BITS-Compact-Server, Web-Server, Web-WebServer, Web-Common-Http, Web-Default-Doc, Web-Dir-Browsing, Web-Http-Errors, Web-Static-Content, Web-Http-Redirect, Web-App-Dev, Web-Net-Ext, Web-Net-Ext45, Web-ASP, Web-Asp-Net, Web-Asp-Net45, Web-CGI, Web-ISAPI-Ext, Web-ISAPI-Filter, Web-Health, Web-Http-Logging, Web-Custom-Logging, Web-Log-Libraries, Web-Request-Monitor, Web-Http-Tracing, Web-Performance, Web-Stat-Compression, Web-Security, Web-Filtering, Web-Basic-Auth, Web-IP-Security, Web-Url-Auth, Web-Windows-Auth, Web-Mgmt-Tools, Web-Mgmt-Console, Web-Mgmt-Compat, Web-Metabase, Web-Lgcy-Mgmt-Console, Web-Lgcy-Scripting, Web-WMI, Web-Scripting-Tools, Web-Mgmt-Service, RDC) | Where-Object {$_.installstate -eq "Installed"}}).count
        $TCMNetFeat = (Invoke-Command -Session $TCMSession -ScriptBlock {(get-windowsfeature -name NET-Framework-Features, NET-Framework-Core) | Where-Object {$_.installstate -eq "Installed"}}).count
        $TCMSQLInstalled = (Invoke-Command -Session $TCMSession -ScriptBlock {get-service -name "MSSQLSERVER" -ErrorAction SilentlyContinue}).name.count
        $TCMADKInstalled = (Invoke-Command -Session $TCMSession -ScriptBlock {test-path "C:\Program Files (x86)\Windows Kits\10\Assessment and deployment kit"})
        $TCMSCCMInstalled = (Invoke-Command -Session $TCMSession -ScriptBlock {get-service -name "SMS_EXECUTIVE" -ErrorAction SilentlyContinue}).name.count
        $TCMSCCMConsoleInstalled = (Invoke-Command -Session $TCMSession -ScriptBlock {test-path "C:\Program Files (x86)\Microsoft Configuration Manager\AdminConsole\bin\Microsoft.ConfigurationManagement.exe"})
        $TCMSession | Remove-PSSession
    }
    it 'CM VHDX Should Exist' {$TCMVHDXExists | should be $true}
    it 'CM Should Exist' {$TCMExists | should be 1}
    it 'CM Should be running' {$TCMRunning | should be 1}
    it 'CM IP Address' -Skip:(!($TCMExists -eq 1 -and $TCMRunning -eq 1)) {$TCMIPAddress | should be "$ipsub`11"}
    it 'CM has access to Internet' -Skip:(!($TCMExists -eq 1 -and $TCMRunning -eq 1)) {$TCMTestInternet | should be $true}
    it "CM has access to $DomainFQDN" -Skip:(!($TCMExists -eq 1 -and $TCMRunning -eq 1)) {$TCMTestDomain | Should be $true}
    it 'CM .Net Feature installed' -Skip:(!($TCMExists -eq 1 -and $TCMRunning -eq 1)) {$TCMNetFeat | should be 2}
    it 'CM Features are installed' -Skip:(!($TCMExists -eq 1 -and $TCMRunning -eq 1)) {$TCMFeat | should be 44}
    it 'CM SQL Instance is installed' -Skip:(!($TCMExists -eq 1 -and $TCMRunning -eq 1)) {$TCMSQLInstalled | should be 1}
    it 'CM ADK Installed' -Skip:(!($TCMExists -eq 1 -and $TCMRunning -eq 1)) {$TCMADKInstalled | should be $true}
    it 'CM SCCM Installed' -Skip:(!($TCMExists -eq 1 -and $TCMRunning -eq 1)) {$TCMSCCMInstalled | should be 1}
    it 'CM SCCM Console Installed' -Skip:(!($TCMExists -eq 1 -and $TCMRunning -eq 1)) {$TCMSCCMConsoleInstalled | should be $true }
}

Describe "CA" -tag ("CA","VM") {
    $TCAVHDXExists = (Test-Path -path "$vmpath\$($CAname)c.vhdx")
    $TCAExists = (get-vm -name $CAname -ErrorAction SilentlyContinue).count
    $TCARunning = (get-vm -name $CAname -ErrorAction SilentlyContinue | Where-Object {$_.State -match "Running"}).count
    if ($TCAExists -eq 1 -and $TCARunning -eq 1) {
        $TCASession = new-PSSession -VMName $CAname -Credential $localadmin -ErrorAction SilentlyContinue
        if(!($TCASession)) {$TCASession = new-PSSession -VMName $CAname -Credential $domuser}
        $TCAIPAddress = (Invoke-Command -Session $TCASession -ScriptBlock {(Get-NetIPAddress -AddressFamily IPv4 -PrefixOrigin Manual -ErrorAction SilentlyContinue).ipaddress})
        $TCATestInternet = (Invoke-Command -Session $TCASession -ScriptBlock {test-netconnection "8.8.8.8" -WarningAction SilentlyContinue}).PingSucceeded
        $TCATestDomain = (Invoke-Command -Session $TCASession -ScriptBlock {param($d)Test-NetConnection $d -erroraction SilentlyContinue -WarningAction SilentlyContinue} -ArgumentList $DomainFQDN ).PingSucceeded
        $TCAFeat = (Invoke-Command -Session $TCASession -ScriptBlock {(get-windowsfeature -name Adcs-Cert-Authority | Where-Object {$_.installstate -eq "Installed"}).count})
        $TCASession | Remove-PSSession
    }
    it 'CA VHDX Should Exist' {$TCAVHDXExists | should be $true}
    it 'CA Should Exist' {$TCAExists | should be 1}
    it 'CA Should be running' {$TCARunning | should be 1}
    it 'CA IP Address' -Skip:(!($TCAExists -eq 1 -and $TCARunning -eq 1)) {$TCAIPAddress | should be "$ipsub`12"}
    it 'CA has access to Internet' -Skip:(!($TCAExists -eq 1 -and $TCARunning -eq 1)) {$TCATestInternet | should be $true}
    it "CA has access to $DomainFQDN" -Skip:(!($TCAExists -eq 1 -and $TCARunning -eq 1)) {$TCATestDomain | Should be $true}
    it 'CA Feature is installed' -Skip:(!($TCAExists -eq 1 -and $TCARunning -eq 1)) {$TCAFeat | should be 1}

}

Describe "vSwitch" -tag ("Network", "ENV") {
    $lresult = (Get-VMSwitch -Name $swname -ErrorAction SilentlyContinue).count
    $Iresult = (Get-VMSwitch -Name "Internet" -ErrorAction SilentlyContinue).count
    it "Lab VMSwitch Should exist" {$lresult | should be 1}
    it 'Internet VSwitch should exist' {$Iresult | should be 1}
}

Describe "Reference-VHDX" -Tag ("VM", "Template") {
    $result = (Test-Path -Path "$RefVHDX")
    it 'VHDX Should exist' {$result | should be $true}
}

Describe "Test Source Media" -tag ("VM","ENV") {
    $Win16iso = (Test-path -Path "$($config.WIN16ISO)")
    $SQLMedia = (Test-Path -Path "$($config.SQLISO)")
    $adkmedia = (Test-Path -Path "$($config.ADKPATH)")
    $SCCMMedia = (Test-Path -Path "$($config.SCCMPath)")
    $net35path = (Test-Path -Path "$($config.WINNET35CAB)")
    $unattendpath = $config.REFVHDX -replace ($config.REFVHDX.split('\') | Select-Object -last 1), "Unattended.xml"
    $win16unattend = (test-path "$($unattendpath)")
    it 'Windows 2016 source media' {$Win16iso | should be $true }
    it 'Windows 2016 Unattend' {$win16unattend | should be $true }
    it 'SQL 2016 Media' {$SQLMedia | Should be $true }
    it 'ADK Content' {$adkmedia | should be $true }
    it 'SCCM Media' {$SCCMMedia | should be $true }
    it '.net 3.5 Media' {$net35path | should be $true }
}