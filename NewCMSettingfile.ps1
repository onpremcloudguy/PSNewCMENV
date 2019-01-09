function New-CMSettingfile{
param(
    [switch]
    $cas,
    [switch]
    $PRI,
    $ServerName,
    $cmsitecode,
    $domainFQDN,
    $sqlsettings,
    $CasServerName,
    [ValidateSet("TP","Prod")]
    [string]
    $ver
)
if($ver -eq "Prod"){
    if($cas.IsPresent -and $pri.IsPresent){
        $hashident = @{'action' = 'InstallPrimarySite'}
    }
    else {
        $hashident = @{'action' = 'InstallCAS'}
    }
}    
elseif($ver -eq "TP"){
    $hashident = @{'action' = 'InstallPrimarySite';
        'Preview' = "1"
    }
}
if ($cas.IsPresent -and !($pri.IsPresent)){
    $hashoptions = @{'ProductID' = 'EVAL';
        'SiteCode' = $cmsitecode;
        'SiteName' = "Tech Preview $cmsitecode";
        'SMSInstallDir' = 'C:\Program Files\Microsoft Configuration Manager';
        'SDKServer' = "$cmOSName.$DomainFQDN";
        'PrerequisiteComp' = "$SCCMDLPreDown";
        'PrerequisitePath' = "C:\DATA\SCCM\DL";
        'MobileDeviceLanguage' = "0";
        'AdminConsole' = "1";
        'JoinCEIP' = "0";
    }
}
else {
    $hashoptions = @{'ProductID' = 'EVAL';
        'SiteCode' = $cmsitecode;
        'SiteName' = "Tech Preview $cmsitecode";
        'SMSInstallDir' = 'C:\Program Files\Microsoft Configuration Manager';
        'SDKServer' = "$cmOSName.$DomainFQDN";
        'RoleCommunicationProtocol' = "HTTPorHTTPS";
        'ClientsUsePKICertificate' = "0";
        'PrerequisiteComp' = "$SCCMDLPreDown";
        'PrerequisitePath' = "C:\DATA\SCCM\DL";
        'ManagementPoint' = "$cmOSName.$DomainFQDN";
        'ManagementPointProtocol' = "HTTP";
        'DistributionPoint' = "$cmOSName.$DomainFQDN";
        'DistributionPointProtocol' = "HTTP";
        'DistributionPointInstallIIS' = "0";
        'AdminConsole' = "1";
        'JoinCEIP' = "0";
    }
}
$hashSQL = @{'SQLServerName' = "$cmOSName.$DomainFQDN";
    'SQLServerPort' = '1433';
    'DatabaseName' = "CM_$cmsitecode";
    'SQLSSBPort' = '4022';
    'SQLDataFilePath' = "$($sqlsettings.DefaultFile)";
    'SQLLogFilePath' = "$($sqlsettings.DefaultLog)"
}
$hashCloud = @{
    'CloudConnector' = "1";
    'CloudConnectorServer' = "$cmOSName.$DomainFQDN"
}
$hashSCOpts = @{
}
if(![string]::IsNullOrEmpty($CasServerName))
{
    $hashHierarchy = @{
        'CCARSiteServer' = "$CasServerName"
    }
}
else {
    $hashHierarchy = @{}
}
$HASHCMInstallINI = @{'Identification' = $hashident;
    'Options' = $hashoptions;
    'SQLConfigOptions' = $hashSQL;
    'CloudConnectorOptions' = $hashCloud;
    'SystemCenterOptions' = $hashSCOpts;
    'HierarchyExpansionOption' = $hashHierarchy
}
$CMInstallINI = ""
Foreach ($i in $HASHCMInstallINI.keys) {
    $CMInstallINI += "[$i]`r`n"
    foreach ($j in $($HASHCMInstallINI[$i].keys | Sort-Object)) {
        $CMInstallINI += "$j=$($HASHCMInstallINI[$i][$j])`r`n"
    }
    $CMInstallINI += "`r`n"
}
return $CMInstallINI
}