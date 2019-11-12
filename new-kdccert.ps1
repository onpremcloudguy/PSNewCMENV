function new-kdccert {
    param(
        $Domain
    )
    $ConfigContext = ([ADSI]"LDAP://RootDSE").ConfigurationNamingContext
    $ADSI = [ADSI]"LDAP://CN=Certificate Templates,CN=Public Key Services,CN=Services,$ConfigContext"
    $newcert = $adsi.create("pKICertificateTemplate", "CN=Domain Controller Authentication (KDC)")
    $newcert.put("distinguishedName", "CN=DomainControllerAuthentication(KDC),CN=Certificate Templates,CN=Public Key Services,CN=Services,$ConfigContext")
    $newcert.put("flags", "131168")
    $newcert.put("displayName", "Domain Controller Authentication (KDC)")
    $newcert.put("revision", "100")
    $newcert.put("pKIDefaultKeySpec", "1")
    $newcert.put("pKIMaxIssuingDepth", "0")
    $newcert.put("pKICriticalExtensions", @("2.5.29.17", "2.5.29.15"))
    $newcert.put("pKIExtendedKeyUsage", @("1.3.6.1.4.1.311.20.2.2", "1.3.6.1.5.5.7.3.1", "1.3.6.1.5.2.3.5", "1.3.6.1.5.5.7.3.2"))
    $newcert.put("msPKI-RA-Signature", "0")
    $newcert.put("msPKI-Enrollment-Flag", "32")
    $newcert.put("msPKI-Private-Key-Flag", "84213760")
    $newcert.put("msPKI-Certificate-Name-Flag", "406847488")
    $newcert.put("msPKI-Minimal-Key-Size", "2048")
    $newcert.put("msPKI-Template-Schema-Version", "4")
    $newcert.put("msPKI-Template-Minor-Revision", "3")
    $newcert.put("msPKI-Cert-Template-OID", "1.3.6.1.4.1.311.21.8.1228481.4920039.15089813.8619623.7815189.17.10339185.7330727")
    $newcert.put("msPKI-Certificate-Application-Policy", @("1.3.6.1.4.1.311.20.2.2", "1.3.6.1.5.5.7.3.1", "1.3.6.1.5.2.3.5", "1.3.6.1.5.5.7.3.2"))
    $newcert.put("msPKI-Supersede-Templates", @("DomainController", "DomainControllerAuthentication", "KerberosAuthentication"))
    $newcert.put("msPKI-RA-Application-Policies", "msPKI-Asymmetric-Algorithm``PZPWSTR``RSA``msPKI-Hash-Algorithm``PZPWSTR``SHA256``msPKI-Key-Usage``DWORD``16777215``msPKI-Symmetric-Algorithm``PZPWSTR``3DES``msPKI-Symmetric-Key-Length``DWORD``168``")
    $newcert.put("pKIKeyUsage", [Byte[]]( "160", "0" ))
    $newcert.put("pKIExpirationPeriod", ([Byte[]](0, 192, 171, 149, 139, 163, 252, 255)))
    $newcert.put("pKIOverlapPeriod", ([Byte[]](0, 128, 166, 10, 255, 222, 255, 255)))
    $newcert.setinfo() | Out-Null
    $AdObj = New-Object System.Security.Principal.NTAccount("$domain\Domain Controllers")
    $identity = $AdObj.Translate([System.Security.Principal.SecurityIdentifier])
    $adRights = "ReadProperty, WriteProperty, ExtendedRight"
    $type = "Allow"
    $ACE = New-Object System.DirectoryServices.ActiveDirectoryAccessRule($identity, $adRights, $type)
    $newcert.psbase.ObjectSecurity.SetAccessRule($ACE)
    $newcert.psbase.commitchanges()
    $p = Start-Process "C:\Windows\System32\certtmpl.msc" -PassThru
    Start-Sleep 2
    $p | Stop-Process            
    Add-CATemplate -name "Domain Controller Authentication (KDC)" -ErrorAction SilentlyContinue -Force
}
