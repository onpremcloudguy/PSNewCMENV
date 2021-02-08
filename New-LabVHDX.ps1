function new-LabVHDX {
    param
    (
        [parameter(Mandatory)]    
        [string]
        $vhdxpath,
        [parameter(Mandatory)]
        [string]
        $unattend,
        [parameter]
        [switch]
        $core,
        [parameter(Mandatory)]
        [string]
        $WinISO,
        [parameter(Mandatory)]
        [String]
        $WinNet35Cab
    )
    $convmod = get-module -ListAvailable -Name 'Hyper-ConvertImage'
    if ($convmod.count -ne 1) {
        Install-Module -name 'Hyper-ConvertImage' -Scope AllUsers
    }
    else {
        Update-Module -Name 'Hyper-ConvertImage'    
    }
    Import-module -name 'Hyper-ConvertImage'
    $cornum = 2
    if ($core.IsPresent) { $cornum = 3 }else { $cornum = 4 }
    Convert-WindowsImage -SourcePath $WinISO -Edition $cornum -VhdType Dynamic -VhdFormat VHDX -VhdPath $vhdxpath -DiskLayout UEFI -SizeBytes 127gb -UnattendPath $unattend
    $drive = (Mount-VHD -Path $vhdxpath -Passthru | Get-Disk | Get-Partition | Where-Object { $_.type -eq 'Basic' }).DriveLetter
    new-item "$drive`:\data" -ItemType Directory | Out-Null
    $netfiles = get-childitem -Path $winnet35cab -Filter "*netfx*"
    foreach ($net in $netfiles) {
        Copy-Item -Path $net.fullname -Destination "$drive`:\data\$($net.name)"
    }
    Dismount-VHD -Path $vhdxpath
}