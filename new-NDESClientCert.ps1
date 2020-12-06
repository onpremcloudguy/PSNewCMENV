function new-NDESClientcert {
    param(
        $Domain,
        $ndessvc
    )
    $ConfigContext = ([ADSI]"LDAP://RootDSE").ConfigurationNamingContext
    $ADSI = [ADSI]"LDAP://CN=Certificate Templates,CN=Public Key Services,CN=Services,$ConfigContext"
    $newcert = $adsi.create("pKICertificateTemplate", "CN=ConfigMgrWebServer")
    $newcert.put("distinguishedName", "CN=ConfigMgrWebServer,CN=Certificate Templates,CN=Public Key Services,CN=Services,$ConfigContext")
    $newcert.put("flags", "131649")
    $newcert.put("displayName", "ConfigMgr Web Server")
    $newcert.put("revision", "100")
    $newcert.put("pKIDefaultKeySpec", "1")
    $newcert.put("pKIMaxIssuingDepth", "0")
    $newcert.put("pKICriticalExtensions", "2.5.29.15")
    $newcert.put("pKIExtendedKeyUsage", "1.3.6.1.5.5.7.3.1")
    $newcert.put("msPKI-RA-Signature", "0")
    $newcert.put("msPKI-Enrollment-Flag", "8")
    $newcert.put("msPKI-Private-Key-Flag", "16842752")
    $newcert.put("msPKI-Certificate-Name-Flag", "1")
    $newcert.put("msPKI-Minimal-Key-Size", "2048")
    $newcert.put("msPKI-Template-Schema-Version", "2")
    $newcert.put("msPKI-Template-Minor-Revision", "1")
    $newcert.put("msPKI-Cert-Template-OID", "1.3.6.1.4.1.311.21.8.9297300.10481922.2378919.4036973.687234.60.11634013.16673656")
    $newcert.put("msPKI-Certificate-Application-Policy", "1.3.6.1.5.5.7.3.1")
    $newcert.put("pKIKeyUsage", [Byte[]]( "160", "0" ))
    $newcert.put("pKIExpirationPeriod", ([Byte[]](0, 192, 171, 149, 139, 163, 252, 255)))
    $newcert.put("pKIOverlapPeriod", ([Byte[]](0, 128, 166, 10, 255, 222, 255, 255)))
    $newcert.setinfo() | Out-Null
    $AdObj = New-Object System.Security.Principal.NTAccount("$domain\SCCM Servers")
    $identity = $AdObj.Translate([System.Security.Principal.SecurityIdentifier])
    $adRights = "ReadProperty, WriteProperty, ExtendedRight,GenericExecute"
    $type = "Allow"
    $ACE = New-Object System.DirectoryServices.ActiveDirectoryAccessRule($identity, $adRights, $type)
    $newcert.psbase.ObjectSecurity.SetAccessRule($ACE)
    $AdObj = New-Object System.Security.Principal.NTAccount("$domain\$ndessvc")
    $identity = $AdObj.Translate([System.Security.Principal.SecurityIdentifier])
    $adRights = "ReadProperty, WriteProperty, ExtendedRight,GenericExecute"
    $type = "Allow"
    $ACE = New-Object System.DirectoryServices.ActiveDirectoryAccessRule($identity, $adRights, $type)
    $newcert.psbase.ObjectSecurity.SetAccessRule($ACE)
    $newcert.psbase.commitchanges()
    $p = Start-Process "C:\Windows\System32\certtmpl.msc" -PassThru
    Start-Sleep 2
    $p | Stop-Process            
    Add-CATemplate -name "ConfigMgrWebServer" -ErrorAction SilentlyContinue -Force
}