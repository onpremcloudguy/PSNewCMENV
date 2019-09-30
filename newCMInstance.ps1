function new-CMInstance{
    param(
        $cmsession,
        $cmname,
        $cmsitecode,
        $domainfqdn,
        [ValidateSet("TP","Prod")]
        [string]
        $ver,
        $ipsub,
        $domainnetbios,
        [ValidateSet("CAS","PRI","CASPRI")]
        [string]
        $CMServerType,
        [string]
        $CASIPAddress
    )
    if($CMServerType -eq "CASPRI")
    {
        $casservername = Invoke-Command -Session $cmsession -ScriptBlock {param($i) [System.Net.Dns]::GetHostEntry("$i").hostname} -ArgumentList $CASIPAddress
    }
    $cmOSName = Invoke-Command -Session $cmsession -ScriptBlock {$env:COMPUTERNAME}
    $sqlsettings = invoke-command -Session $cmsession -ScriptBlock {(new-object ('Microsoft.SqlServer.Management.Smo.Server') $env:COMPUTERNAME).Settings | Select-Object DefaultFile, Defaultlog}
    write-logentry -message "Host name for $cmname is: $cmosname"
    $cmsitecode = "$cmsitecode"
    if($CMServerType -eq "CASPRI")
    {
        $cminstallini = New-CMSettingfile -CMServerType $CMServerType -ServerName $cmOSName -cmsitecode "PRI" -domainFQDN $DomainFQDN -sqlsettings $sqlsettings -ver $ver -CasServerName $casservername -CasSiteCode $cmsitecode
    }
    else {
        $cminstallini = New-CMSettingfile -CMServerType $CMServerType -ServerName $cmOSName -cmsitecode $cmsitecode -domainFQDN $DomainFQDN -sqlsettings $sqlsettings -ver $ver
    }
    
    write-logentry -message "CM install ini for $cmname is: $cminstallini" -type information
    Invoke-Command -Session $cmsession -ScriptBlock {param($ini) new-item -ItemType file -Path c:\CMinstall.ini -Value $INI -Force} -ArgumentList $CMInstallINI | out-null
    Invoke-Command -Session $cmsession -ScriptBlock {Add-ADGroupMember "SCCM Servers" -Members "$($env:computername)$"}
    if(!($CMServerType -eq "CASPRI")){
        invoke-command -Session $cmsession -scriptblock {start-process -filepath "c:\data\sccm\smssetup\bin\x64\extadsch.exe" -wait}
        write-logentry -message "AD Schema has been exteded for SCCM on $domainfqdn"
    }
    write-logentry -message "SCCM installation process has started on $cmname this will take some time so grab a coffee" -type information
    Invoke-Command -Session $cmsession -ScriptBlock {Start-Process -FilePath "C:\DATA\SCCM\SMSSETUP\bin\x64\setup.exe" -ArgumentList "/script c:\CMinstall.ini" -wait}
    if(!($cas.IsPresent)){
    write-logentry -message "SCCM has been installed on $cmname" -type information
    invoke-command -session $cmsession -scriptblock {
        param($ipsub, $sitecode, $Subnetname, $DomainDN)
            while (!(Test-Path "C:\Program Files (x86)\Microsoft Configuration Manager\AdminConsole\bin\ConfigurationManager.psd1" -ErrorAction SilentlyContinue -WarningAction SilentlyContinue)) {
                start-sleep -Seconds 20
            }
            import-module "C:\Program Files (x86)\Microsoft Configuration Manager\AdminConsole\bin\ConfigurationManager.psd1"; 
            if($null -eq (Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) {New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $env:COMPUTERNAME | Out-Null}
            Set-Location "$((Get-PSDrive -PSProvider CMSite).name)`:"; 
            New-CMBoundary -Type IPSubnet -Value "$($ipsub)0/24" -name $Subnetname | Out-Null;
            New-CMBoundaryGroup -name $Subnetname -DefaultSiteCode "$((Get-PSDrive -PSProvider CMSite).name)" | Out-Null;
            Add-CMBoundaryToGroup -BoundaryName $Subnetname -BoundaryGroupName $Subnetname;
            $Schedule = New-CMSchedule -RecurInterval Minutes -Start "2012/10/20 00:00:00" -End "2013/10/20 00:00:00" -RecurCount 10;
            Set-CMDiscoveryMethod -ActiveDirectorySystemDiscovery -SiteCode $sitecode -Enabled $True -EnableDeltaDiscovery $True -PollingSchedule $Schedule -AddActiveDirectoryContainer "LDAP://$domaindn" -Recursive -ErrorAction SilentlyContinue;
            Get-CMDevice | Where-Object {$_.ADSiteName -eq "Default-First-Site-Name"} | Install-CMClient -IncludeDomainController $true -AlwaysInstallClient $true -SiteCode $sitecode;
        } -ArgumentList $ipsub, $cmsitecode, $domainnetbios, ("dc=" + ($DomainFQDN.Split('.') -join ",dc="))
    }
    return $cmOSName
}