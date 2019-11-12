function new-NDESUsercert {
    param(
        $Domain
    )
    $ConfigContext = ([ADSI]"LDAP://RootDSE").ConfigurationNamingContext
    $ADSI = [ADSI]"LDAP://CN=Certificate Templates,CN=Public Key Services,CN=Services,$ConfigContext"
    $newcert = $adsi.create("pKICertificateTemplate", "CN=NDES User")
    $newcert.put("distinguishedName", "CN=NDESUser,CN=Certificate Templates,CN=Public Key Services,CN=Services,$ConfigContext")
    $newcert.put("flags", "131642")
    $newcert.put("displayName", "NDES User")
    $newcert.put("revision", "100")
    $newcert.put("pKIDefaultKeySpec", "1")
    $newcert.put("pKIMaxIssuingDepth", "0")
    $newcert.put("pKICriticalExtensions", @("2.5.29.7", "2.5.29.15"))
    $newcert.put("pKIExtendedKeyUsage", @("1.3.6.1.5.5.7.3.4", "1.3.6.1.4.1.311.10.3.4", "1.3.6.1.5.5.7.3.2", "2.5.29.37.0"))
    $newcert.put("msPKI-RA-Signature", "0")
    $newcert.put("msPKI-Enrollment-Flag", "1")
    $newcert.put("msPKI-Private-Key-Flag", "16842752")
    $newcert.put("msPKI-Certificate-Name-Flag", "1")
    $newcert.put("msPKI-Minimal-Key-Size", "2048")
    $newcert.put("msPKI-Template-Schema-Version", "2")
    $newcert.put("msPKI-Template-Minor-Revision", "2")
    $newcert.put("msPKI-Cert-Template-OID", "1.3.6.1.4.1.311.21.8.12344063.8726395.2247602.10184630.9318525.198.2328079.11028052")
    $newcert.put("msPKI-Certificate-Application-Policy", @("1.3.6.1.5.5.7.3.4", "1.3.6.1.4.1.311.10.3.4", "1.3.6.1.5.5.7.3.2", "2.5.29.37.0"))
    $newcert.put("pKIKeyUsage", [Byte[]]( "32" ))
    $newcert.put("pKIExpirationPeriod", ([Byte[]](0, 64, 57, 135, 46, 225, 254, 255)))
    $newcert.put("pKIOverlapPeriod", ([Byte[]](0, 128, 166, 10, 255, 222, 255, 255)))
    $newcert.setinfo() | Out-Null
    $AdObj = New-Object System.Security.Principal.NTAccount("$domain\SCCM Servers")
    $identity = $AdObj.Translate([System.Security.Principal.SecurityIdentifier])
    $adRights = "ReadProperty, WriteProperty, ExtendedRight,GenericExecute"
    $type = "Allow"
    $ACE = New-Object System.DirectoryServices.ActiveDirectoryAccessRule($identity, $adRights, $type)
    $newcert.psbase.ObjectSecurity.SetAccessRule($ACE)
    $newcert.psbase.commitchanges()
    $p = Start-Process "C:\Windows\System32\certtmpl.msc" -PassThru
    Start-Sleep 2
    $p | Stop-Process            
    Add-CATemplate -name "NDES User" -ErrorAction SilentlyContinue -Force
}