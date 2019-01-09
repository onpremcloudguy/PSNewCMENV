function new-CMSQLsettingsINI {
    param(
        $domainnetbios,
        $admpwd    
    )
    $SQLHash = @{'ACTION'                = '"Install"';
        'SUPPRESSPRIVACYSTATEMENTNOTICE' = '"TRUE"';
        'IACCEPTROPENLICENSETERMS'       = '"TRUE"';
        'ENU'                            = '"TRUE"';
        'QUIET'                          = '"TRUE"';
        'UpdateEnabled'                  = '"TRUE"';
        'USEMICROSOFTUPDATE'             = '"TRUE"';
        'FEATURES'                       = 'SQLENGINE,RS';
        'UpdateSource'                   = '"MU"';
        'HELP'                           = '"FALSE"';
        'INDICATEPROGRESS'               = '"FALSE"';
        'X86'                            = '"FALSE"';
        'INSTANCENAME'                   = '"MSSQLSERVER"';
        'INSTALLSHAREDDIR'               = '"C:\Program Files\Microsoft SQL Server"';
        'INSTALLSHAREDWOWDIR'            = '"C:\Program Files (x86)\Microsoft SQL Server"';
        'INSTANCEID'                     = '"MSSQLSERVER"';
        'RSINSTALLMODE'                  = '"DefaultNativeMode"';
        'SQLTELSVCACCT'                  = '"NT Service\SQLTELEMETRY"';
        'SQLTELSVCSTARTUPTYPE'           = '"Automatic"';
        'INSTANCEDIR'                    = '"C:\Program Files\Microsoft SQL Server"';
        'AGTSVCACCOUNT'                  = '"NT Service\SQLSERVERAGENT"';
        'AGTSVCSTARTUPTYPE'              = '"Manual"';
        'COMMFABRICPORT'                 = '"0"';
        'COMMFABRICNETWORKLEVEL'         = '"0"';
        'COMMFABRICENCRYPTION'           = '"0"';
        'MATRIXCMBRICKCOMMPORT'          = '"0"';
        'SQLSVCSTARTUPTYPE'              = '"Automatic"';
        'FILESTREAMLEVEL'                = '"0"';
        'ENABLERANU'                     = '"FALSE"';
        'SQLCOLLATION'                   = '"SQL_Latin1_General_CP1_CI_AS"';
        'SQLSVCACCOUNT'                  = """$domainnetbios\administrator"""; 
        'SQLSVCPASSWORD'                 = """$admpwd""" 
        'SQLSVCINSTANTFILEINIT'          = '"FALSE"';
        'SQLSYSADMINACCOUNTS'            = """$domainnetbios\administrator"" ""$domainnetbios\Domain Users"""; 
        'SQLTEMPDBFILECOUNT'             = '"1"';
        'SQLTEMPDBFILESIZE'              = '"8"';
        'SQLTEMPDBFILEGROWTH'            = '"64"';
        'SQLTEMPDBLOGFILESIZE'           = '"8"';
        'SQLTEMPDBLOGFILEGROWTH'         = '"64"';
        'ADDCURRENTUSERASSQLADMIN'       = '"FALSE"';
        'TCPENABLED'                     = '"1"';
        'NPENABLED'                      = '"1"';
        'BROWSERSVCSTARTUPTYPE'          = '"Disabled"';
        'RSSVCACCOUNT'                   = '"NT Service\ReportServer"';
        'RSSVCSTARTUPTYPE'               = '"Automatic"';
    }
    $SQLHASHINI = @{'OPTIONS' = $SQLHash}
    $SQLInstallINI = ""
    Foreach ($i in $SQLHASHINI.keys) {
        $SQLInstallINI += "[$i]`r`n"
        foreach ($j in $($SQLHASHINI[$i].keys | Sort-Object)) {
            $SQLInstallINI += "$j=$($SQLHASHINI[$i][$j])`r`n"
        }
        $SQLInstallINI += "`r`n"
    }
    return $SQLInstallINI
}