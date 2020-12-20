function new-ENV {
    param(
        [Parameter(ParameterSetName = 'ENVClass')]
        [env]
        $ENVConfig,
        [Parameter(ParameterSetName = 'NoClass')]
        [string]
        $vmpath,
        [Parameter(ParameterSetName = 'NoClass')]
        [string]
        $RefVHDX,
        [Parameter(ParameterSetName = 'NoClass')]
        [string]
        $Win16ISOPath,
        [Parameter(ParameterSetName = 'NoClass')]
        [string]
        $Win16Net35Cab,
        [Parameter(ParameterSetName = 'NoClass')]
        [string]
        $network,
        [Parameter(ParameterSetName = 'NoClass')]
        [string]
        $DefaultPwd
    )
    if (!$PSBoundParameters.ContainsKey('ENVConfig')) {
        $ENVConfig = [env]::new()
        $ENVConfig.vmpath = $vmpath
        $ENVConfig.RefVHDX = $RefVHDX
        $ENVConfig.Win16ISOPath = $Win16ISOPath
        $ENVConfig.Win16Net35Cab = $Win16Net35Cab
        $ENVConfig.network = $network
        $ENVConfig.DefaultPwd = $DefaultPwd
    }
    Write-LogEntry -Type Information -Message "Creating the base requirements for Lab Environment"
    Write-LogEntry -Type Information -Message "ENV Settings are: $($envconfig | ConvertTo-Json)"
    if ((Invoke-Pester -TagFilter "RefVHDX" -PassThru -Output None).result -eq "Passed") {
        Write-LogEntry -Type Information -Message "Reference image already exists in: $($ENVConfig.RefVHDX)"
    }
    else {
        if (!(Test-Path $ENVConfig.vmpath)) { New-Item -ItemType Directory -Force -Path $ENVConfig.vmpath }
        else {
            if (!(Test-Path "$($scriptpath)\unattended.xml")) {
                New-UnattendXml -admpwd $ENVConfig.DefaultPwd -outfile "$($scriptpath)\unattended.xml"
            }
            Write-LogEntry -Type Information -Message "Reference image doesn't exist, will create it now"
            new-LabVHDX -VHDXPath $ENVConfig.RefVHDX -Unattend "$($scriptpath)\unattended.xml" -WinISO $ENVConfig.Win16ISOPath -WinNet35Cab $ENVConfig.Win16Net35Cab
            Write-LogEntry -Type Information -Message "Reference image has been created in: $($ENVConfig.RefVHDX)"
        }
    }
    if ((invoke-pester -TagFilter "ExternalSwitch" -PassThru -Output None).result -ne 'Passed') {
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
            $Selected = $oOptions | Where-Object { $_.Item -eq $selection }
            New-VMSwitch -Name 'Internet' -NetAdapterName $selected.name -AllowManagementOS:$true | Out-Null
            Write-LogEntry -Type Information -Message "Internet vSwitch has been created."
        }
    }
    if ((invoke-pester -TagFilter "LabSwitch" -PassThru -Output None).result -ne 'Passed') {
        Write-LogEntry -Type Information -Message "Private vSwitch named $($ENVConfig.network) does not exist"
        New-VMSwitch -Name $ENVConfig.network -SwitchType Private | Out-Null
        Write-LogEntry -Type Information -Message "Private vSwitch named $($ENVConfig.network) has been created."
    }
    Write-LogEntry -Type Information -Message "Base requirements for Lab Environment has been met"
}