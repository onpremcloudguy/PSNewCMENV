function New-CMSQLInstance {
    param(
        $cmname,
        $cmsession,
        $config,
        $domainnetbios,
        $admpwd
    )
    Add-VMDvdDrive -VMName $cmname -ControllerNumber 0 -ControllerLocation 1
    Set-VMDvdDrive -Path $config.SQLISO -VMName $cmname -ControllerNumber 0 -ControllerLocation 1
    $sqldisk = Invoke-Command -session $cmsession -ScriptBlock {(Get-PSDrive -PSProvider FileSystem | where-object {$_.name -ne "c"}).root}
    write-logentry -message "$($config.sqliso) mounted as $sqldisk to $cmname" -type information
    $sqlinstallini = new-CMSQLsettingsINI -domainnetbios $domainnetbios -admpwd $admpwd
    write-logentry -message "SQL Configuration for $cmname is: $sqlinstallini" -type information
    Invoke-Command -Session $cmsession -ScriptBlock {param($ini) new-item -ItemType file -Path c:\ConfigurationFile.INI -Value $INI -Force} -ArgumentList $SQLInstallINI | out-null
    write-logentry -message "SQL installation has started on $cmname this can take some time" -type information
    Invoke-Command -Session $cmsession -ScriptBlock {param($drive)start-process -FilePath "$drive`Setup.exe" -Wait -ArgumentList "/ConfigurationFile=c:\ConfigurationFile.INI /IACCEPTSQLSERVERLICENSETERMS"} -ArgumentList $sqldisk
    write-logentry -message "SQL installation has completed on $cmname told you it would take some time" -type information
    Invoke-Command -Session $cmsession -ScriptBlock {
        [reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") | Out-Null
        $srv = New-Object Microsoft.SQLServer.Management.Smo.Server($env:COMPUTERNAME)
        if ($srv.status) {
            $srv.Configuration.MaxServerMemory.ConfigValue = 8kb
            $srv.Configuration.MinServerMemory.ConfigValue = 4kb   
            $srv.Configuration.Alter()
        }
    }
    Set-VMDvdDrive -VMName $cmname -Path $null
    Invoke-Command -session $cmsession -ScriptBlock {Add-WindowsFeature UpdateServices-Services, UpdateServices-db} | Out-Null
    invoke-command -session $cmsession -scriptblock {start-process -filepath "C:\Program Files\Update Services\Tools\WsusUtil.exe" -ArgumentList "postinstall CONTENT_DIR=C:\WSUS SQL_INSTANCE_NAME=$env:COMPUTERNAME" -Wait}
    invoke-command -session $cmsession -ScriptBlock {start-process -FilePath "C:\windows\system32\msiexec.exe" -ArgumentList "/I c:\data\sccm\dl\sqlncli.msi /QN REBOOT=ReallySuppress"}
    write-logentry -message "SQL ISO dismounted from $cmname" -type information
}