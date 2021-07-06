. .\Lab.Classes.ps1
function Get-EnvSettings {
    param (
        $scriptpath
    )
    $testconfig = [testframes]::new()
    $config = Get-Content "$scriptpath\env.json" -Raw | ConvertFrom-Json
    $envConfig = $config.ENVConfig | Where-Object { $_.env -eq $config.env }
    $admpwd = $envConfig.AdminPW
    $testconfig.localadmin = new-object -typename System.Management.Automation.PSCredential -argumentlist ".\administrator", (ConvertTo-SecureString -String $admpwd -AsPlainText -Force)
    $testconfig.domuser = new-object -typename System.Management.Automation.PSCredential -argumentlist "$($envconfig.DomainNetBiosName)\administrator", (ConvertTo-SecureString -String $admpwd -AsPlainText -Force)
    $testconfig.vmpath = $envConfig.VMPath
    $testconfig.swname = $envConfig.SwitchName
    $testconfig.DomainFQDN = $envconfig.DomainFQDN
    $testconfig.RefVHDX = $config.REFVHDX
    return $testconfig
}
#region RRAS
function Get-rrasVHDXstate {
    param (
        $spath
    )
    $rrassettings = Get-EnvSettings -scriptpath $spath
    $RRASConfig = [RRAS]::new()
    $rrasconfig.load("$(split-path $rrassettings.vmpath)\RRASConfig.json")
    return test-path $RRASConfig.VHDXpath
}
function Get-rrasVMexists {
    param (
        $spath
    )
    $rrassettings = Get-EnvSettings -scriptpath $spath
    $RRASConfig = [RRAS]::new()
    $rrasconfig.load("$(split-path $rrassettings.vmpath)\RRASConfig.json")
    return (Get-vm -Name $RRASConfig.Name -ErrorAction SilentlyContinue).count
}
function Get-rrasVMrunning {
    param (
        $spath
    )
    $rrassettings = Get-EnvSettings -scriptpath $spath
    $RRASConfig = [RRAS]::new()
    $rrasconfig.load("$(split-path $rrassettings.vmpath)\RRASConfig.json")
    return (Get-vm -Name $RRASConfig.Name -ErrorAction SilentlyContinue | Where-Object { $_.State -match "Running" }).Count
}
function Get-rrasVMfeatures {
    param (
        $spath
    )
    $rrassettings = Get-EnvSettings -scriptpath $spath
    $RRASConfig = [RRAS]::new()
    $rrasfeat = "Not Installed"
    if ((Get-rrasVMexists -spath $spath) -and (Get-rrasVMrunning -spath $spath)) {
        $rrasconfig.load("$(split-path $rrassettings.vmpath)\RRASConfig.json")
        $trrasSession = New-PSSession -VMName $RRASConfig.Name -Credential $rrassettings.localadmin
        $rrasfeat = (Invoke-Command -Session $trrasSession -ScriptBlock { (Get-windowsfeature -name routing).installstate }).value
        $trrasSession | Remove-PSSession
    }
    return $rrasfeat
}
function Get-rrasVMExternalNIC {
    param (
        $spath
    )
    $rrassettings = Get-EnvSettings -scriptpath $spath
    $RRASConfig = [RRAS]::new()
    $rrasconfig.load("$(split-path $rrassettings.vmpath)\RRASConfig.json")
    $rrasEXTrename = $false
    if ((Get-rrasVMexists -spath $spath) -and (Get-rrasVMrunning -spath $spath)) {
        $trrasSession = New-PSSession -VMName $RRASConfig.Name -Credential $rrassettings.localadmin
        $rrasEXTrename = (Invoke-Command -Session $trrasSession -ScriptBlock { Get-NetAdapter -Physical -Name "External" -ErrorAction SilentlyContinue }).name
        $trrasSession | Remove-PSSession
    }
    return $rrasEXTrename
}
function Get-rrasVMLabNIC {
    param (
        $spath
    )
    $rrassettings = Get-EnvSettings -scriptpath $spath
    $RRASConfig = [RRAS]::new()
    $rrasconfig.load("$(split-path $rrassettings.vmpath)\RRASConfig.json")
    $rrasLabrename = $false
    if ((Get-rrasVMexists -spath $spath) -and (Get-rrasVMrunning -spath $spath)) {
        $trrasSession = New-PSSession -VMName $RRASConfig.Name -Credential $rrassettings.localadmin
        $rrasLabrename = ((Invoke-Command -Session $trrasSession -ScriptBlock { param($n)Get-NetAdapter -Physical -Name $n -ErrorAction SilentlyContinue } -ArgumentList $RRASConfig.network).name -eq $RRASConfig.network)
        $trrasSession | Remove-PSSession
    }
    return $rrasLabrename
}
function Get-rrasVMVPN {
    param (
        $spath
    )
    $rrassettings = Get-EnvSettings -scriptpath $spath
    $RRASConfig = [RRAS]::new()
    $rrasconfig.load("$(split-path $rrassettings.vmpath)\RRASConfig.json")
    $rrasVPN = $false
    if ((Get-rrasVMexists -spath $spath) -and (Get-rrasVMrunning -spath $spath)) {
        $trrasSession = New-PSSession -VMName $RRASConfig.Name -Credential $rrassettings.localadmin
        $rrasVPN = (Invoke-Command -Session $trrasSession -ScriptBlock { if ((Get-command Get-RemoteAccess -ErrorAction SilentlyContinue).count -eq 1) { Get-RemoteAccess -ErrorAction SilentlyContinue } })
        $trrasSession | Remove-PSSession
    }
    return $rrasVPN
}
function Get-rrasVMIP {
    param (
        $spath
    )
    $rrassettings = Get-EnvSettings -scriptpath $spath
    $RRASConfig = [RRAS]::new()
    $rrasconfig.load("$(split-path $rrassettings.vmpath)\RRASConfig.json")
    $rrasVMIP = $false
    if ((Get-rrasVMexists -spath $spath) -and (Get-rrasVMrunning -spath $spath)) {
        $trrasSession = New-PSSession -VMName $RRASConfig.Name -Credential $rrassettings.localadmin
        $rrasVMIP = (Invoke-Command -Session $trrasSession -ScriptBlock { param($n)(Get-NetIPAddress -interfacealias $n -AddressFamily IPv4 -ErrorAction SilentlyContinue).ipaddress } -ArgumentList $RRASConfig.network)# -eq $RRASConfig.ipaddress)
        $trrasSession | Remove-PSSession
    }
    return $rrasVMIP
}
function Get-rrasVMInternet {
    param (
        $spath
    )
    $rrassettings = Get-EnvSettings -scriptpath $spath
    $RRASConfig = [RRAS]::new()
    $rrasconfig.load("$(split-path $rrassettings.vmpath)\RRASConfig.json")
    $rrasvmip = $false
    if ((Get-rrasVMexists -spath $spath) -and (Get-rrasVMrunning -spath $spath)) {
        $trrasSession = New-PSSession -VMName $RRASConfig.Name -Credential $rrassettings.localadmin
        $rrasVMIP = (Invoke-Command -Session $trrasSession -ScriptBlock { test-netconnection "8.8.8.8" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue }).PingSucceeded
        $trrasSession | Remove-PSSession
    }
    return $rrasVMIP
}
#endregion

#region ENV
function Get-RefVHDXstate {
    param (
        $spath
    )
    $EnvSettings = Get-EnvSettings -scriptpath $spath
    return test-path -path $EnvSettings.refvhdx
}
function Get-ExternalSwitch {
    if ((Get-VMSwitch -Name "Internet" -ErrorAction SilentlyContinue).count -eq 1) {
        return $true
    }
    else {
        return $false
    }
}
function Get-LabSwitch {
    param(
        $spath
    )
    $EnvSettings = Get-EnvSettings -scriptpath $spath
    if ((Get-VMSwitch -Name $EnvSettings.swname -ErrorAction SilentlyContinue).count -eq 1) {
        return $true
    }
    else {
        return $false
    }
}
#endregion

#region DC
function Get-DCVHDXstate {
    param (
        $spath
    )
    $DCsettings = Get-EnvSettings -scriptpath $spath
    $DCConfig = [DC]::new()
    $DCconfig.load("$($DCsettings.vmpath)\DCConfig.json")
    return test-path $DCConfig.VHDXpath
}
function Get-DCVMexists {
    param (
        $spath
    )
    $DCsettings = Get-EnvSettings -scriptpath $spath
    $DCConfig = [DC]::new()
    $DCconfig.load("$($DCsettings.vmpath)\DCConfig.json")
    return (Get-vm -Name $DCConfig.Name -ErrorAction SilentlyContinue).count
}
function Get-DCVMrunning {
    param (
        $spath
    )
    $DCsettings = Get-EnvSettings -scriptpath $spath
    $DCConfig = [DC]::new()
    $DCconfig.load("$($DCsettings.vmpath)\DCConfig.json")
    return (Get-vm -Name $DCConfig.Name -ErrorAction SilentlyContinue | Where-Object { $_.State -match "Running" }).Count
}
function Get-DCVMIP {
    param (
        $spath
    )
    $DCsettings = Get-EnvSettings -scriptpath $spath
    $DCConfig = [DC]::new()
    $DCconfig.load("$($DCsettings.vmpath)\DCConfig.json")
    $DCVMIP = $false
    if ((Get-DCVMexists -spath $spath) -and (Get-DCVMrunning -spath $spath)) {
        $tDCSession = New-PSSession -VMName $DCConfig.Name -Credential $DCsettings.domuser
        $DCVMIP = Invoke-Command -Session $tDCSession -ScriptBlock { (Get-NetIPAddress -AddressFamily IPv4 -PrefixOrigin Manual -ErrorAction SilentlyContinue).ipaddress }
        $tDCSession | Remove-PSSession
    }
    return ($dcvmip -eq $DCconfig.IPAddress)
}
function Get-DCVMFeature {
    param (
        $spath
    )
    $DCsettings = Get-EnvSettings -scriptpath $spath
    $DCConfig = [DC]::new()
    $DCconfig.load("$($DCsettings.vmpath)\DCConfig.json")
    if ((Get-DCVMexists -spath $spath) -and (Get-DCVMrunning -spath $spath)) {
        $tDCSession = New-PSSession -VMName $DCConfig.Name -Credential $DCsettings.domuser
        $DCFeat = (Invoke-Command -Session $TDCSession -ScriptBlock { (Get-WindowsFeature -name AD-Domain-Services).installstate }).value
        $tDCSession | Remove-PSSession
    }
    return ($DCFeat -eq "Installed")
}
function Get-DCVMInternet {
    param (
        $spath
    )
    $DCsettings = Get-EnvSettings -scriptpath $spath
    $DCConfig = [DC]::new()
    $DCconfig.load("$($DCsettings.vmpath)\DCConfig.json")
    $DCvmip = $false
    if ((Get-DCVMexists -spath $spath) -and (Get-DCVMrunning -spath $spath)) {
        $tDCSession = New-PSSession -VMName $DCConfig.Name -Credential $DCsettings.domuser
        $DCVMIP = (Invoke-Command -Session $tDCSession -ScriptBlock { test-netconnection "8.8.8.8" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue }).PingSucceeded
        $tDCSession | Remove-PSSession
    }
    return $DCVMIP
}
function Get-DCVMPromoted {
    param (
        $spath
    )
    $DCsettings = Get-EnvSettings -scriptpath $spath
    $DCConfig = [DC]::new()
    $DCconfig.load("$($DCsettings.vmpath)\DCConfig.json")
    $DCvmPromoted = $false
    if ((Get-DCVMexists -spath $spath) -and (Get-DCVMrunning -spath $spath)) {
        $tDCSession = New-PSSession -VMName $DCConfig.Name -Credential $DCsettings.domuser
        $DCvmPromoted = (Invoke-Command -Session $TDCSession -ScriptBlock { Get-Service -Name "NTDS" -ErrorAction SilentlyContinue }).status
        $tDCSession | Remove-PSSession
    }
    return ($DCvmPromoted -eq "running")
}
function Get-DCVMDHCPScope {
    param (
        $spath
    )
    $DCsettings = Get-EnvSettings -scriptpath $spath
    $DCConfig = [DC]::new()
    $DCconfig.load("$($DCsettings.vmpath)\DCConfig.json")
    $DCVMDHCPScope = $false
    if ((Get-DCVMexists -spath $spath) -and (Get-DCVMrunning -spath $spath)) {
        $tDCSession = New-PSSession -VMName $DCConfig.Name -Credential $DCsettings.domuser
        $DCVMDHCPScope = Invoke-Command -Session $TDCSession -ScriptBlock {
            if (Get-command Get-DhcpServerv4Scope -ErrorAction SilentlyContinue) {
                Get-DhcpServerv4Scope -ErrorAction SilentlyContinue -warningaction SilentlyContinue
            }
        }
        $tDCSession | Remove-PSSession
    }
    return ($DCVMDHCPScope[0].State -eq "Active")
}
function Get-DCVMCMGroupExists {
    [cmdletbinding()]
    param (
        $spath
    )
    $DCsettings = Get-EnvSettings -scriptpath $spath
    $DCConfig = [DC]::new()
    $DCconfig.load("$($DCsettings.vmpath)\DCConfig.json")
    $DCVMCMGroupExists = $false
    if ((Get-DCVMexists -spath $spath) -and (Get-DCVMrunning -spath $spath)) {
        $tDCSession = New-PSSession -VMName $DCConfig.Name -Credential $DCsettings.domuser
        $DCVMCMGroupExists = Invoke-Command -Session $TDCSession -ScriptBlock {
            if (Get-Command Get-ADGroup -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) {
                Get-ADGroup -Filter "name -eq 'SCCM Servers'" -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
            }
        }
        $tDCSession | Remove-PSSession
    }
    if ($DCVMCMGroupExists | Where-Object {$_.Name -eq 'SCCM Servers'}) {
        return $true
    }
    else {
        return $false
    }
}
#endregion

#region CA
function Get-CAVHDXstate {
    param (
        $spath
    )
    $CAsettings = Get-EnvSettings -scriptpath $spath
    $CAConfig = [CA]::new()
    $CAconfig.load("$($CAsettings.vmpath)\CAConfig.json")
    return test-path $CAConfig.VHDXpath
}
function Get-CAVMexists {
    param (
        $spath
    )
    $CAsettings = Get-EnvSettings -scriptpath $spath
    $CAConfig = [CA]::new()
    $CAconfig.load("$($CAsettings.vmpath)\CAConfig.json")
    return (Get-vm -Name $CAConfig.Name -ErrorAction SilentlyContinue).count
}
function Get-CAVMrunning {
    param (
        $spath
    )
    $CAsettings = Get-EnvSettings -scriptpath $spath
    $CAConfig = [CA]::new()
    $CAconfig.load("$($CAsettings.vmpath)\CAConfig.json")
    return (Get-vm -Name $CAConfig.Name -ErrorAction SilentlyContinue | Where-Object { $_.State -match "Running" }).Count
}
function Get-CAVMIP {
    param (
        $spath
    )
    $CAsettings = Get-EnvSettings -scriptpath $spath
    $CAConfig = [CA]::new()
    $CAconfig.load("$($CAsettings.vmpath)\CAConfig.json")
    $CAVMIP = $false
    if ((Get-CAVMexists -spath $spath) -and (Get-CAVMrunning -spath $spath)) {
        $tCASession = New-PSSession -VMName $CAConfig.Name -Credential $CAsettings.localadmin
        $CAVMIP = (Invoke-Command -Session $tCASession -ScriptBlock { (Get-NetIPAddress -AddressFamily IPv4 -PrefixOrigin Manual -ErrorAction SilentlyContinue).ipaddress })
        $tCASession | Remove-PSSession
    }
    return ($CAvmip -eq $CAconfig.IPAddress)
}
function Get-CAVMFeature {
    param (
        $spath
    )
    $CAsettings = Get-EnvSettings -scriptpath $spath
    $CAConfig = [CA]::new()
    $CAconfig.load("$($CAsettings.vmpath)\CAConfig.json")
    if ((Get-CAVMexists -spath $spath) -and (Get-CAVMrunning -spath $spath)) {
        $tCASession = New-PSSession -VMName $CAConfig.Name -Credential $CAsettings.localadmin
        $CAFeat = (Invoke-Command -Session $TCASession -ScriptBlock { (Get-WindowsFeature -name Adcs-Cert-Authority).installstate }).value
        $tCASession | Remove-PSSession
    }
    return ($CAFeat -eq "Installed")
}
function Get-CAVMInternet {
    param (
        $spath
    )
    $CAsettings = Get-EnvSettings -scriptpath $spath
    $CAConfig = [CA]::new()
    $CAconfig.load("$($CAsettings.vmpath)\CAConfig.json")
    $CAvmip = $false
    if ((Get-CAVMexists -spath $spath) -and (Get-CAVMrunning -spath $spath)) {
        $tCASession = New-PSSession -VMName $CAConfig.Name -Credential $CAsettings.localadmin
        $CAVMIP = (Invoke-Command -Session $tCASession -ScriptBlock { test-netconnection "8.8.8.8" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue }).PingSucceeded
        $tCASession | Remove-PSSession
    }
    return $CAVMIP
}
function Get-CAVMDomain {
    param (
        $spath
    )
    $CAsettings = Get-EnvSettings -scriptpath $spath
    $CAConfig = [CA]::new()
    $CAconfig.load("$($CAsettings.vmpath)\CAConfig.json")
    $CAvmDom = $false
    if ((Get-CAVMexists -spath $spath) -and (Get-CAVMrunning -spath $spath)) {
        $tCASession = New-PSSession -VMName $CAConfig.Name -Credential $CAsettings.localadmin
        $CAvmDom = (Invoke-Command -Session $TCASession -ScriptBlock { param($d)Test-NetConnection $d -erroraction SilentlyContinue -WarningAction SilentlyContinue } -ArgumentList $CAConfig.domainFQDN ).PingSucceeded
        $tCASession | Remove-PSSession
    }
    return $CAvmDom
}

#endregion

#region CMPri
function Get-CMPriVHDXstate {
    param (
        $spath
    )
    $CMPrisettings = Get-EnvSettings -scriptpath $spath
    $CMConfig = [CM]::new()
    $CMConfig.load("$($CMPrisettings.vmpath)\CMConfig.json")
    return test-path $CMConfig.VHDXpath
}
function Get-CMPriVMexists {
    param (
        $spath
    )
    $CMPrisettings = Get-EnvSettings -scriptpath $spath
    $CMConfig = [CM]::new()
    $CMConfig.load("$($CMPrisettings.vmpath)\CMConfig.json")
    return (Get-vm -Name $CMConfig.Name -ErrorAction SilentlyContinue).count
}
function Get-CMPriVMrunning {
    param (
        $spath
    )
    $CMPrisettings = Get-EnvSettings -scriptpath $spath
    $CMConfig = [CM]::new()
    $CMConfig.load("$($CMPrisettings.vmpath)\CMConfig.json")
    return (Get-vm -Name $CMConfig.Name -ErrorAction SilentlyContinue | Where-Object { $_.State -match "Running" }).Count
}
function Get-CMPriVMIP {
    param (
        $spath
    )
    $CMPrisettings = Get-EnvSettings -scriptpath $spath
    $CMConfig = [CM]::new()
    $CMConfig.load("$($CMPrisettings.vmpath)\CMConfig.json")
    $CMPriVMIP = $false
    if ((Get-CMPriVMexists -spath $spath) -and (Get-CMPriVMrunning -spath $spath)) {
        $tCMPriSession = New-PSSession -VMName $CMConfig.Name -Credential $CMPrisettings.localadmin
        $CMPriVMIP = (Invoke-Command -Session $tCMPriSession -ScriptBlock { (Get-NetIPAddress -AddressFamily IPv4 -PrefixOrigin Manual -ErrorAction SilentlyContinue).ipaddress })
        $tCMPriSession | Remove-PSSession
    }
    return ($CMPrivmip -eq $CMConfig.IPAddress)
}
function Get-CMPriVMFeature {
    param (
        $spath
    )
    $CMPrisettings = Get-EnvSettings -scriptpath $spath
    $CMConfig = [CM]::new()
    $CMConfig.load("$($CMPrisettings.vmpath)\CMConfig.json")
    if ((Get-CMPriVMexists -spath $spath) -and (Get-CMPriVMrunning -spath $spath)) {
        $tCMPriSession = New-PSSession -VMName $CMConfig.Name -Credential $CMPrisettings.localadmin
        $CMPriFeat = (Invoke-Command -Session $TCMPriSession -ScriptBlock { (Get-WindowsFeature -name BITS, BITS-IIS-Ext, BITS-Compact-Server, Web-Server, Web-WebServer, Web-Common-Http, Web-Default-Doc, Web-Dir-Browsing, Web-Http-Errors, Web-Static-Content, Web-Http-Redirect, Web-App-Dev, Web-Net-Ext, Web-Net-Ext45, Web-ASP, Web-Asp-Net, Web-Asp-Net45, Web-CGI, Web-ISAPI-Ext, Web-ISAPI-Filter, Web-Health, Web-Http-Logging, Web-Custom-Logging, Web-Log-Libraries, Web-Request-Monitor, Web-Http-Tracing, Web-Performance, Web-Stat-Compression, Web-Security, Web-Filtering, Web-Basic-Auth, Web-IP-Security, Web-Url-Auth, Web-Windows-Auth, Web-Mgmt-Tools, Web-Mgmt-Console, Web-Mgmt-Compat, Web-Metabase, Web-Lgcy-Mgmt-Console, Web-Lgcy-Scripting, Web-WMI, Web-Scripting-Tools, Web-Mgmt-Service, RDC).installstate }).value
        $tCMPriSession | Remove-PSSession
    }
    $res = ($CMPriFeat -ne "Installed").count
    return ($res -eq 0)
}
function Get-CMPriVMnetFeature {
    param (
        $spath
    )
    $CMPrisettings = Get-EnvSettings -scriptpath $spath
    $CMConfig = [CM]::new()
    $CMConfig.load("$($CMPrisettings.vmpath)\CMConfig.json")
    if ((Get-CMPriVMexists -spath $spath) -and (Get-CMPriVMrunning -spath $spath)) {
        $tCMPriSession = New-PSSession -VMName $CMConfig.Name -Credential $CMPrisettings.localadmin
        $CMPriFeat = (Invoke-Command -Session $TCMPriSession -ScriptBlock { (Get-WindowsFeature -name NET-Framework-Features, NET-Framework-Core).installstate }).value
        $tCMPriSession | Remove-PSSession
    }
    $res = ($CMPriFeat -ne "Installed").count
    return ($res -eq 0)
}
function Get-CMPriVMInternet {
    param (
        $spath
    )
    $CMPrisettings = Get-EnvSettings -scriptpath $spath
    $CMConfig = [CM]::new()
    $CMConfig.load("$($CMPrisettings.vmpath)\CMConfig.json")
    $CMPrivmip = $false
    if ((Get-CMPriVMexists -spath $spath) -and (Get-CMPriVMrunning -spath $spath)) {
        $tCMPriSession = New-PSSession -VMName $CMConfig.Name -Credential $CMPrisettings.localadmin
        $CMPriVMIP = (Invoke-Command -Session $tCMPriSession -ScriptBlock { test-netconnection "8.8.8.8" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue }).PingSucceeded
        $tCMPriSession | Remove-PSSession
    }
    return $CMPriVMIP
}
function Get-CMPriVMDomain {
    param (
        $spath
    )
    $CMPrisettings = Get-EnvSettings -scriptpath $spath
    $CMConfig = [CM]::new()
    $CMConfig.load("$($CMPrisettings.vmpath)\CMConfig.json")
    $CMPrivmDom = $false
    if ((Get-CMPriVMexists -spath $spath) -and (Get-CMPriVMrunning -spath $spath)) {
        $tCMPriSession = New-PSSession -VMName $CMConfig.Name -Credential $CMPrisettings.localadmin
        $CMPrivmDom = (Invoke-Command -Session $TCMPriSession -ScriptBlock { param($d)Test-NetConnection $d -erroraction SilentlyContinue -WarningAction SilentlyContinue } -ArgumentList $CMConfig.domainFQDN ).PingSucceeded
        $tCMPriSession | Remove-PSSession
    }
    return $CMPrivmDom
}
function Get-CMPriVMSQLSvc {
    param (
        $spath
    )
    $CMPrisettings = Get-EnvSettings -scriptpath $spath
    $CMConfig = [CM]::new()
    $CMConfig.load("$($CMPrisettings.vmpath)\CMConfig.json")
    $CMPriVMSQLSvc = $false
    if ((Get-CMPriVMexists -spath $spath) -and (Get-CMPriVMrunning -spath $spath)) {
        $tCMPriSession = New-PSSession -VMName $CMConfig.Name -Credential $CMPrisettings.localadmin
        $CMPriVMSQLSvc = (Invoke-Command -Session $tCMPriSession -ScriptBlock { get-service -name "MSSQLSERVER" -ErrorAction SilentlyContinue }).name.count
        $tCMPriSession | Remove-PSSession
    }
    return $CMPriVMSQLSvc
}
function Get-CMPriVMADK {
    param (
        $spath
    )
    $CMPrisettings = Get-EnvSettings -scriptpath $spath
    $CMConfig = [CM]::new()
    $CMConfig.load("$($CMPrisettings.vmpath)\CMConfig.json")
    $CMPriVMADK = $false
    if ((Get-CMPriVMexists -spath $spath) -and (Get-CMPriVMrunning -spath $spath)) {
        $tCMPriSession = New-PSSession -VMName $CMConfig.Name -Credential $CMPrisettings.localadmin
        $CMPriVMADK = (Invoke-Command -Session $tCMPriSession -ScriptBlock { test-path "C:\Program Files (x86)\Windows Kits\10\Assessment and deployment kit" -ErrorAction SilentlyContinue })
        $tCMPriSession | Remove-PSSession
    }
    return $CMPriVMADK
}
function Get-CMPriVMSVRGRP {
    param (
        $spath
    )
    $CMPrisettings = Get-EnvSettings -scriptpath $spath
    $CMConfig = [CM]::new()
    $CMConfig.load("$($CMPrisettings.vmpath)\CMConfig.json")
    $CMPriVMSVRGRP = $false
    if ((Get-CMPriVMexists -spath $spath) -and (Get-CMPriVMrunning -spath $spath)) {
        $tCMPriSession = New-PSSession -VMName $CMConfig.Name -Credential $CMPrisettings.domuser
        $CMPriVMSVRGRP = (Invoke-Command -Session $tCMPriSession -ScriptBlock { Get-ADGroupMember "SCCM Servers" | Where-Object { $_.name -eq $env:computername } } -ErrorAction SilentlyContinue).name.count
        $tCMPriSession | Remove-PSSession
    }
    return $CMPriVMSVRGRP
}
function Get-CMPriVMCMInstalled {
    param (
        $spath
    )
    $CMPrisettings = Get-EnvSettings -scriptpath $spath
    $CMConfig = [CM]::new()
    $CMConfig.load("$($CMPrisettings.vmpath)\CMConfig.json")
    $CMPriVMCMInstalled = $false
    if ((Get-CMPriVMexists -spath $spath) -and (Get-CMPriVMrunning -spath $spath)) {
        $tCMPriSession = New-PSSession -VMName $CMConfig.Name -Credential $CMPrisettings.domuser
        $CMPriVMCMInstalled = (Invoke-Command -Session $tCMPriSession -ScriptBlock { get-service -name "SMS_EXECUTIVE" -ErrorAction SilentlyContinue }).name.count
        $tCMPriSession | Remove-PSSession
    }
    return $CMPriVMCMInstalled
}
function Get-CMPriVMCMConsoleInstalled {
    param (
        $spath
    )
    $CMPrisettings = Get-EnvSettings -scriptpath $spath
    $CMConfig = [CM]::new()
    $CMConfig.load("$($CMPrisettings.vmpath)\CMConfig.json")
    $CMPriVMCMConsoleInstalled = $false
    if ((Get-CMPriVMexists -spath $spath) -and (Get-CMPriVMrunning -spath $spath)) {
        $tCMPriSession = New-PSSession -VMName $CMConfig.Name -Credential $CMPrisettings.domuser
        $CMPriVMCMConsoleInstalled = (Invoke-Command -Session $tCMPriSession -ScriptBlock { test-path "C:\Program Files (x86)\Microsoft Configuration Manager\AdminConsole\bin\Microsoft.ConfigurationManagement.exe" })
        $tCMPriSession | Remove-PSSession
    }
    return $CMPriVMCMConsoleInstalled
}
function Get-CMPriVMCMBoundary {
    param (
        $spath
    )
    $CMPrisettings = Get-EnvSettings -scriptpath $spath
    $CMConfig = [CM]::new()
    $CMConfig.load("$($CMPrisettings.vmpath)\CMConfig.json")
    $CMPriVMCMBoundary = $false
    if ((Get-CMPriVMexists -spath $spath) -and (Get-CMPriVMrunning -spath $spath -and (Get-CMPriVMCMConsoleInstalled -spath $spath))) {
        $tCMPriSession = New-PSSession -VMName $CMConfig.Name -Credential $CMPrisettings.domuser
        Invoke-Command -Session $tCMPriSession -ScriptBlock { param ($sitecode) import-module "$(($env:SMS_ADMIN_UI_PATH).remove(($env:SMS_ADMIN_UI_PATH).Length -4, 4))ConfigurationManager.psd1"; if ($null -eq (Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) { New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $env:COMPUTERNAME }; Set-Location "$((Get-PSDrive -PSProvider CMSite).name)`:" } -ArgumentList $CMConfig.cmsitecode
        $CMPriVMCMBoundary = (Invoke-Command -Session $tCMPriSession -ScriptBlock { param($subname) Get-CMBoundary -name $subname } -ArgumentList $CMConfig.network).displayname.count
        $tCMPriSession | Remove-PSSession
    }
    return $CMPriVMCMBoundary
}
function Get-CMPriVMCMDiscovery {
    param (
        $spath
    )
    $CMPrisettings = Get-EnvSettings -scriptpath $spath
    $CMConfig = [CM]::new()
    $CMConfig.load("$($CMPrisettings.vmpath)\CMConfig.json")
    $CMPriVMCMDiscovery = $false
    if ((Get-CMPriVMexists -spath $spath) -and (Get-CMPriVMrunning -spath $spath -and (Get-CMPriVMCMConsoleInstalled -spath $spath))) {
        $tCMPriSession = New-PSSession -VMName $CMConfig.Name -Credential $CMPrisettings.domuser
        Invoke-Command -Session $tCMPriSession -ScriptBlock { param ($sitecode) import-module "$(($env:SMS_ADMIN_UI_PATH).remove(($env:SMS_ADMIN_UI_PATH).Length -4, 4))ConfigurationManager.psd1"; if ($null -eq (Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) { New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $env:COMPUTERNAME }; Set-Location "$((Get-PSDrive -PSProvider CMSite).name)`:" } -ArgumentList $CMConfig.cmsitecode
        $CMPriVMCMDiscovery = (Invoke-Command -Session $tCMPriSession -ScriptBlock { Get-CMDiscoveryMethod -Name ActiveDirectorySystemDiscovery }).flag
        $tCMPriSession | Remove-PSSession
    }
    return $CMPriVMCMDiscovery
}
#if ($TCMSCCMConsoleInstalled) {
#    Invoke-Command -Session $tCMPriSession -ScriptBlock { param ($sitecode) import-module "$(($env:SMS_ADMIN_UI_PATH).remove(($env:SMS_ADMIN_UI_PATH).Length -4, 4))ConfigurationManager.psd1"; if ($null -eq (Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) { New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $env:COMPUTERNAME }; Set-Location "$((Get-PSDrive -PSProvider CMSite).name)`:" } -ArgumentList $CMConfig.cmsitecode
#    $TCMBoundary = (Invoke-Command -Session $tCMPriSession -ScriptBlock { param($subname) Get-CMBoundary -name $subname } -ArgumentList $CMConfig.network).displayname.count
#    $TCMDiscovery = (Invoke-Command -Session $tCMPriSession -ScriptBlock { Get-CMDiscoveryMethod -Name ActiveDirectorySystemDiscovery }).flag
#}
#endregion