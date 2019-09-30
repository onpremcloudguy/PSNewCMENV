function New-UnattendXml {
    [CmdletBinding()]
    Param
    (
        # The password to have unattnd.xml set the local Administrator to
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [Alias('password')] 
        [string]
        $admpwd,
        [Parameter(Mandatory)]
        [string]
        $outfile,
        [Parameter]
        [switch]
        $WKS,
        [Parameter]
        [string]
        $domainFQDN,
        [Parameter]
        [string]
        $Adminuname,
        [Parameter]
        [string]
        $domainNetBios
    )
    if ($WKS.IsPresent) {
        $unattendTemplate = [xml]@" 
        <?xml version="1.0" encoding="utf-8"?>
        <unattend xmlns="urn:schemas-microsoft-com:unattend">
            <settings pass="specialize">
                <component name="Microsoft-Windows-UnattendedJoin" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
                    <Identification>
                        <Credentials>
                            <Domain><<DomNetBios>></Domain>
                            <Password><<ADM_PWD>></Password>
                            <Username><<AdminUname>></Username>
                        </Credentials>
                        <JoinDomain><<DomainFQDN>></JoinDomain>
                    </Identification>
                </component>
            </settings>
        </unattend>
"@
        $unattendTemplate -replace "<<ADM_PWD>>", $admpwd 
        $unattendTemplate -replace "<<DomNetBios>>", $domainNetBios 
        $unattendTemplate -replace "<<AdminUname>>", $Adminuname
        $unattendTemplate -replace "<<DomainFQDN>>", $domainFQDN
        $unattendTemplate | Out-File -FilePath $outfile -Encoding utf8
    }
    else {
        $unattendTemplate = [xml]@" 
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <servicing>
        <package action="install" permanence="removable">
            <assemblyIdentity name="Microsoft-Windows-NetFx3-OnDemand-Package" version="10.0.14393.0" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" />
            <source location="c:\data\microsoft-windows-netfx3-ondemand-package.cab" />
        </package>
    </servicing>
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <UserAccounts>
                <AdministratorPassword>
                    <Value><<ADM_PWD>></Value> 
                    <PlainText>True</PlainText> 
                </AdministratorPassword>
            </UserAccounts>
            <OOBE>
                <VMModeOptimizations>
                    <SkipNotifyUILanguageChange>true</SkipNotifyUILanguageChange>
                    <SkipWinREInitialization>true</SkipWinREInitialization>
                </VMModeOptimizations>
                <SkipMachineOOBE>true</SkipMachineOOBE>
                <HideEULAPage>true</HideEULAPage>
                <HideLocalAccountScreen>true</HideLocalAccountScreen>
                <ProtectYourPC>3</ProtectYourPC>
                <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
                <NetworkLocation>Work</NetworkLocation>
                <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
            </OOBE>
        </component>
        <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <InputLocale>en-au</InputLocale>
            <SystemLocale>en-us</SystemLocale>
            <UILanguage>en-au</UILanguage>
            <UILanguageFallback>en-us</UILanguageFallback>
            <UserLocale>en-au</UserLocale>
        </component>
    </settings>
</unattend>
"@
        $unattendTemplate -replace "<<ADM_PWD>>", $admpwd | Out-File -FilePath $outfile -Encoding utf8
    }
}