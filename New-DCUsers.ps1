Function New-DCUsers {
    param(
        [Parameter()]
        [PSCustomObject]
        $UserList,
        [Parameter()]
        [pscredential]
        $DomAdmin,
        [Parameter()]
        [string]
        $DCVM,
        [Parameter()]
        [string]
        $domainname,
        [Parameter()]
        [string]
        $newpwd
    )
    $ouname = "AADusers"
    $psses = New-PSSession -VMName $DCVM -Credential $DomAdmin
    $oucount = (Invoke-Command -Session $psses -ScriptBlock { Param($ou)(Get-ADOrganizationalUnit -filter * | where-Object { $_.name -eq $ou }).Name } -ArgumentList $ouname).count
    if ($oucount -eq 0) {
        invoke-command -Session $psses -ScriptBlock { Param($ou)new-ADOrganizationalUnit $ou } -ArgumentList $ouname
    }
    $ou = Invoke-Command -Session $psses -ScriptBlock { Param($ou)Get-ADOrganizationalUnit -filter * | where-Object { $_.name -eq $ou } } -ArgumentList $ouname
    foreach ($user in $UserList) {
        Invoke-Command -Session $psses -ScriptBlock { Param($fn, $sn, $dn, $ou, $pw)if("$fn.$sn".Length -gt 19){$sam = ("$fn.$sn").substring(0,19)} else {$sam= "$fn.$sn"};new-aduser -name "$fn.$sn" -UserPrincipalName "$fn.$sn@$dn" -path $ou -samaccountname $sam -GivenName $fn -Surname $sn -enabled $true -AccountPassword (ConvertTo-SecureString -String $pw -AsPlainText -Force)} -ArgumentList $user.FirstName.replace("+","").replace(' ',''), $user.lastname.Replace("+","").replace(' ',''), $domainname, $ou.DistinguishedName, $newpwd
    }
    $mgruser = $UserList | Get-Random
    $mgradobj = Invoke-Command -Session $psses -ScriptBlock {Param($fn, $sn) get-aduser -Identity "$fn.$sn"} -ArgumentList $mgruser.FirstName.replace("+","").replace(' ',''), $mgruser.lastname.Replace("+","").replace(' ','')
    foreach ($u in ($UserList | Where-Object {$_.firstname -ne $mgruser.FirstName -and $_.lastname -ne $mgruser.lastname})) {
        if("$($u.FirstName.replace('+','').replace(' ','')).$($u.lastname.Replace('+','').replace(' ',''))".Length -gt 19)
        {
            $sam = ("$($u.FirstName.replace('+','').replace(' ','')).$($u.lastname.Replace('+','').replace(' ',''))").substring(0,19)
        } else {
            $sam= "$($u.FirstName.replace('+','').replace(' ','')).$($u.lastname.Replace('+','').replace(' ',''))"
        }
        Invoke-Command -Session $psses -ScriptBlock { Param($name,$mgr)set-aduser -Identity $name -Manager (get-aduser -identity $mgr.name)} -ArgumentList $sam, $mgradobj
    }
}