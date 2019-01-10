function new-ENV {
    param(
        [Parameter(Mandatory)]
        [pscredential]
        $domuser,
        [Parameter(Mandatory)]
        [string]
        $vmpath,
        [Parameter(Mandatory)]
        [string]
        $RefVHDX,
        [Parameter(Mandatory)]
        [psobject]
        $config,
        [Parameter(Mandatory)]
        [string]
        $swname,
        [Parameter(Mandatory)]
        [string]
        $dftpwd
    )
    if ($domuser -eq $null) {throw "Issue with the Dom User"}
    Write-LogEntry -Type Information -Message "Creating the base requirements for Lab Environment"
    $TREFVHDX = Invoke-Pester -TestName "Reference-VHDX" -PassThru -Show Passed
    if ($TREFVHDX.PassedCount -eq 1) {
        Write-LogEntry -Type Information -Message "Reference image already exists in: $refvhdx"
    }
    else {
        if (!(Test-Path $vmpath)) {New-Item -ItemType Directory -Force -Path $vmpath}
        else {
            if(!(Test-Path "$($scriptpath)\unattended.xml"))
            {
                New-UnattendXml -admpwd $dftpwd -outfile "$($scriptpath)\unattended.xml"
            }
            Write-LogEntry -Type Information -Message "Reference image doesn't exist, will create it now"
            new-LabVHDX -VHDXPath $RefVHDX -Unattend "$($scriptpath)\unattended.xml" -WinISO $config.WIN16ISO -WinNet35Cab $config.WINNET35CAB
            Write-LogEntry -Type Information -Message "Reference image has been created in: $refvhdx"
        }
    }
    $TNetwork = Invoke-Pester -TestName "vSwitch" -PassThru -Show None
    if (($TNetwork.TestResult | Where-Object {$_.name -eq 'Internet VSwitch should exist'}).result -eq 'Failed') {
        Write-LogEntry -Type Information -Message "vSwitch named Internet does not exist"
        $nic = Get-NetAdapter -Physical
        Write-LogEntry -Type Information -Message "Following physical network adaptors found: $($nic.Name -join ",")"
        if ($nic.count -gt 1) {
            Write-Verbose "Multiple Network Adptors found. "
            $i = 1
            $oOptions = @()
            $nic | ForEach-Object {
                $oOptions += [pscustomobject]@{
                    Item = $i
                    Name = $_.Name
                }
                $i++
            }
            $oOptions | Out-Host
            $selection = Read-Host -Prompt "Please make a selection"
            Write-LogEntry -Type Information -Message "The following physical network adaptor has been selected for Internet access: $selection"
            $Selected = $oOptions | Where-Object {$_.Item -eq $selection}
            New-VMSwitch -Name 'Internet' -NetAdapterName $selected.name -AllowManagementOS:$true | Out-Null
            Write-LogEntry -Type Information -Message "Internet vSwitch has been created."
        }
    }
    if (($TNetwork.TestResult | Where-Object {$_.name -eq 'Lab VMSwitch Should exist'}).result -eq 'Failed') {
        Write-LogEntry -Type Information -Message "Private vSwitch named $swname does not exist"
        New-VMSwitch -Name $swname -SwitchType Private | Out-Null
        Write-LogEntry -Type Information -Message "Private vSwitch named $swname has been created."
    }
    Write-LogEntry -Type Information -Message "Base requirements for Lab Environment has been met"
}