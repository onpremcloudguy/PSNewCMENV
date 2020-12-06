BeforeAll {
    . .\v5.Testcases.ps1
}
#region RRAS
Describe 'RRAS' -Tag 'RRAS' {
    it "RRAS VHDX should exist" -tag "RRASVHDX" {
        get-rrasVHDXstate -spath $PSScriptRoot | should -be $true
    }
    it "RRAS VM should exist" -tag "RRASVM" {
        get-rrasVMexists -spath $PSScriptRoot | should -be 1
    }
    it "RRAS is running" -tag "RRASRunning" {
        get-rrasVMrunning -spath $PSScriptRoot | should -be 1
    }
    it "RRAS Features enabled" -Tag "RRASFeatures" {
        get-rrasVMfeatures -spath $PSScriptRoot | should -be "Installed"
    }
    it "RRAS Ext NIC Connected" -Tag "RRASExtNIC" {
        (get-rrasVMExternalNIC -spath $PSScriptRoot) | should -be "External"
    }
    it "RRAS Lab NIC Connected" -Tag "RRASLabNIC" {
        get-rrasVMLabNIC -spath $PSScriptRoot | should -be $true
    }
    it "RRAS Routing" -Tag "RRASVPN" {
        get-rrasvmVPN -spath $PSScriptRoot | should -be "RemoteAccessVpn"
    }
    it "RRAS Lab IP Correct" -tag "RRASLabIP" {
        get-rrasVMIP -spath $PSScriptRoot | should -Be $true
    }
    it "RRAS has Internet" -tag "RRASInternet" {
        get-rrasvminternet -spath $PSScriptRoot | should -Be $true
    }
}
#endregion

#region ENV
Describe 'Env' -Tag 'ENV' {
    it "ReferenceVHDX" -tag "RefVHDX" {
        get-RefVHDXstate -spath $PSScriptRoot | should -be $true
    }
    it 'Internet VSwitch should exist' -tag "ExternalSwitch" { 
        get-ExternalSwitch | should -be $true 
    }
    it "Lab vSwitch should exist" -tag "LabSwitch" {
        get-labswitch -spath $PSScriptRoot | should -be $true
    }
}
#endregion

#region DC
describe "DC" -Tag "DC" {
    it 'DC VHDX Should Exist' -tag "DCVHDX" { 
        get-dcvhdxstate -spath $PSScriptRoot | should -be $true 
    }
    it "DC Should Exist" -tag "DCVM" { 
        get-dcvmexists -spath $PSScriptRoot | should -be 1 
    }
    it "DC Should be running" -tag "DCRunning" { 
        get-dcvmrunning -spath $PSScriptRoot | should -be 1 
    } 
    it "DC IP Set correctly" -tag "DCIP" { 
        get-DCVMIP -spath $PSScriptRoot | should -be $true
    }
    it 'DC Domain Services Installed' -tag "DCFeatures" {
        get-dcvmfeature -spath $PSScriptRoot | should -be $true
    }
    it 'DC has access to Internet' -tag "DCInternet" {
        get-DCVMInternet -spath $PSScriptRoot | should -be $true
    }
    it "DC is promoted" -tag "DCPromo" {
        get-DCVMPromoted -spath $PSScriptRoot | should -be $true
    }
    it "DC DHCP Scope enabled" -tag "DCDHCP" {
        get-DCVMDHCPScope -spath $PSScriptRoot | should -be $true
    }
}
#endregion

#region CA
Describe "CA" -tag "CA" {
    it 'CA VHDX Should Exist' -tag "CAVHDX" { 
        get-CAvhdxstate -spath $PSScriptRoot | should -be $true 
    }
    it "CA Should Exist" -tag "CAVM" { 
        get-CAvmexists -spath $PSScriptRoot | should -be 1 
    }
    it "CA Should be running" -tag "CARunning" { 
        get-CAvmrunning -spath $PSScriptRoot | should -be 1 
    }  
    it "CA IP Set correctly" -tag "CAIP" { 
        get-CAVMIP -spath $PSScriptRoot | should -be $true
    }
    it 'CA Domain Services Installed' -tag "CAFeatures" {
        get-CAvmfeature -spath $PSScriptRoot | should -be $true
    }
    it 'CA has access to Internet' -tag "CAInternet" {
        get-CAVMInternet -spath $PSScriptRoot | should -be $true
    }
    it 'CA can ping domain' -tag 'CADOM' {
        Get-CAVMDomain -spath $PSScriptRoot | should -be $true
    }
}
#endregion