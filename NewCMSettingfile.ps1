function New-CMSettingfile{
param(
    [Parameter(ParameterSetName = 'NoClass')]
    [ValidateSet("CAS","PRI","CASPRI")]
    [string]
    $CMServerType,
    $ServerName,
    $cmsitecode,
    $domainFQDN,
    $sqlsettings,
    [parameter(Mandatory=$false)]
    $CasServerName,
    [parameter(Mandatory=$false)]
    $CasSiteCode,
    [ValidateSet("TP","Prod")]
    [string]
    $ver
)
if($ver -eq "Prod"){
    if($CMServerType -eq "CAS"){
        $hashident = @{'action' = 'InstallCAS'}
    }
    elseif($CMServerType -eq "PRI") {
        $hashident = @{'action' = 'InstallPrimarySite'}
    }
    elseif($CMServerType -eq "CASPRI"){
        $hashident = @{'action' = 'InstallPrimarySite';
            'CDLatest' = "1"}
    }
}    
elseif($ver -eq "TP"){
    $hashident = @{'action' = 'InstallPrimarySite';
        'Preview' = "1"
    }
}
if ($CMServerType -eq "CAS"){
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
elseif ($CMServerType -eq "PRI") {
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
elseif ($CMServerType -eq "CASPRI") {
    $hashoptions = @{'ProductID' = 'EVAL';
        'SiteCode' = $cmsitecode;
        'SiteName' = "Tech Preview";
        'SMSInstallDir' = 'C:\Program Files\Microsoft Configuration Manager';
        'SDKServer' = "$cmOSName.$DomainFQDN";
        'RoleCommunicationProtocol' = "HTTPorHTTPS";
        'ClientsUsePKICertificate' = "0";
        'PrerequisiteComp' = "$SCCMDLPreDown";
        'PrerequisitePath' = "\\$CasServerName\SMS_$CasSiteCode\cd.latest\DL";
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
if($CMServerType -eq "CASPRI")
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