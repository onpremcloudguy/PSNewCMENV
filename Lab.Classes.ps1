class DC {
    [string]$Name
    [int]$cores
    [int]$Ram
    [string]$IPAddress
    [string]$network
    [string]$VHDXpath
    [pscredential]$localadmin
    [string]$domainFQDN
    [string]$AdmPwd
    [pscredential]$domainuser
    [bool]$VMSnapshotenabled
    [string]$refvhdx
    Save ([string] $path) {
        $this | ConvertTo-Json | Out-File $path
    }
    load ([string] $path) {
        $settings = get-content $path | ConvertFrom-Json
        $this.name = $settings.name
        $this.cores = $settings.cores
        $this.Ram = $settings.ram
        $this.IPAddress = $settings.ipaddress
        $this.network = $settings.network
        $this.VHDXpath = $settings.VHDXpath
        $this.domainFQDN = $settings.domainFQDN
        $this.AdmPwd = $settings.AdmPwd
        $this.VMSnapshotenabled = $settings.vmSnapshotenabled
        $this.refvhdx = $settings.refvhdx
    }
}
class RRAS {
    [string]$Name
    [int]$cores
    [int]$ram
    [string]$ipaddress
    [string]$network
    [pscredential]$localadmin
    [bool]$vmSnapshotenabled
    [string]$VHDXpath
    [string]$RefVHDX
    Save ([string] $path) {
        $this | ConvertTo-Json | Out-File $path
    }
    load ([string]$path) {
        $settings = get-content $path | ConvertFrom-Json
        $this.name = $settings.name
        $this.cores = $settings.cores
        $this.ram = $settings.ram
        $this.ipaddress = $settings.ipaddress
        $this.network = $settings.network
        $this.localadmin = $null
        $this.vmSnapshotenabled = $settings.vmSnapshotenabled
        $this.VHDXpath = $settings.VHDXpath
        $this.RefVHDX = $settings.RefVHDX
    }
}
class CM {
    #14
    [string]$name
    [int]$cores #
    [int]$ram #
    [string]$IPAddress #
    [string]$network #
    [string]$VHDXpath #
    [pscredential]$localadmin #
    [pscredential]$domainuser #
    [string]$AdmPwd #
    [string]$domainFQDN #
    [bool]$VMSnapshotenabled #
    [string]$cmsitecode #
    [bool]$SCCMDLPreDownloaded #
    [string]$DCIP #
    [string]$RefVHDX
    [string]$SQLISO
    [string]$SCCMPath
    [string]$ADKPath
    [string]$domainnetbios
    [string]$CMServerType
    [string]$CASIPAddress
    [string]$SCCMVer
    [bool]$Built
    Save ([string] $path) {
        $this | ConvertTo-Json | Out-File $path -Force
    }
    load ([string] $path) {
        $settings = get-content $path | ConvertFrom-Json
        $this.name = $settings.name
        $this.cores = $settings.cores
        $this.ram = $settings.ram
        $this.IPAddress = $settings.ipaddress
        $this.network = $settings.network
        $this.VHDXpath = $settings.VHDXpath
        $this.AdmPwd = $settings.AdmPwd
        $this.domainFQDN = $settings.domainFQDN
        $this.VMSnapshotenabled = $settings.vmSnapshotenabled
        $this.cmsitecode = $settings.cmsitecode
        $this.SCCMDLPreDownloaded = $settings.SCCMDLPreDownloaded
        $this.DCIP = $settings.DCIP
        $this.RefVHDX = $settings.refvhdx
        $this.SQLISO = $settings.SQLISO
        $this.SCCMPath = $settings.SCCMPath
        $this.ADKPath = $settings.ADKPath
        $this.domainnetbios = $settings.domainnetbios
        $this.CMServerType = $settings.CMServerType
        $this.CASIPAddress = $settings.CASIPAddress
        $this.SCCMVer = $settings.SCCMVer
        $this.Built = $settings.built
    }
}
class env {
    [string]$vmpath
    [string]$RefVHDX
    [string]$Win16ISOPath
    [string]$Win16Net35Cab
    [string]$network
    [string]$DefaultPwd
    Save ([string] $path) {
        $this | ConvertTo-Json | Out-File $path
    }
}
class CA {
    [string]$Name
    [int]$cores
    [int]$ram
    [string]$IPAddress
    [string]$network
    [string]$VHDXpath
    [pscredential]$localadmin
    [string]$domainFQDN
    [pscredential]$domainuser
    [bool]$VMSnapshotenabled
    [string]$RefVHDX
    [string]$DCIP
    save ([string] $path) {
        $this | ConvertTo-Json | Out-File $path
    }
    load ([string] $path) {
        $settings = get-content $path | ConvertFrom-Json
        $this.name = $settings.name
        $this.cores = $settings.cores
        $this.Ram = $settings.ram
        $this.IPAddress = $settings.ipaddress
        $this.network = $settings.network
        $this.VHDXpath = $settings.VHDXpath
        $this.domainFQDN = $settings.domainFQDN
        $this.VMSnapshotenabled = $settings.vmSnapshotenabled
        $this.refvhdx = $settings.refvhdx
        $this.DCIP = $Settings.DCIP
    }
}
class CASP {

}
class CASC {

}
class WKS {
    
}

class testframes {
    [pscredential]$localadmin
    [pscredential]$domuser
    [string]$vmpath
    [string]$swname
    [string]$DomainFQDN
    [string]$RefVHDX
}