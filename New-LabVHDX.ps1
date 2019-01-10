function new-LabVHDX {
    param
    (
    [parameter(Mandatory)]    
    [string]
    $vhdxpath,
    [parameter(Mandatory)]
    [string]
    $unattend,
    [parameter(Mandatory)]
    [switch]
    $core,
    [parameter(Mandatory)]
    [string]
    $WinISO,
    [parameter(Mandatory)]
    [String]
    $WinNet35Cab
    )
    $convmod = get-module -ListAvailable -Name 'Convert-WindowsImage'
    if ($convmod.count -ne 1) {
        Install-Module -name 'Convert-WindowsImage' -Scope AllUsers
    }
    else {
        Update-Module -Name 'Convert-WindowsImage'    
    }
    Import-module -name 'Convert-Windowsimage'
    $cornum = 2
    if ($core.IsPresent) {$cornum = 3}else {$cornum = 4}
    Convert-WindowsImage -SourcePath $WinISO -Edition $cornum -VhdType Dynamic -VhdFormat VHDX -VhdPath $vhdxpath -DiskLayout UEFI -SizeBytes 127gb -UnattendPath $unattend
    $drive = (Mount-VHD -Path $vhdxpath -Passthru | Get-Disk | Get-Partition | Where-Object {$_.type -eq 'Basic'}).DriveLetter
    new-item "$drive`:\data" -ItemType Directory | Out-Null
    Copy-Item -Path $WinNet35Cab -Destination "$drive`:\data\microsoft-windows-netfx3-ondemand-package.cab"
    Dismount-VHD -Path $vhdxpath
}