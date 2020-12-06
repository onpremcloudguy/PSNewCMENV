BeforeAll {
    . .\v5.Testcases.ps1
}
#region RRAS
Describe 'RRAS' -Tag 'RRAS' {
    it "RRAS VHDX should exist" -Tag "RRASVHDX" {
        get-rrasVHDXstate -spath $PSScriptRoot | should -be $true
    }
    it "RRAS VM should exist" -Tag "RRASVM" {
        get-rrasVMexists -spath $PSScriptRoot | should -be 1
    }
    it "RRAS is running" -Tag "RRASRunning" {
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
    it "RRAS Lab IP Correct" -Tag "RRASLabIP" {
        get-rrasVMIP -spath $PSScriptRoot | should -Be $true
    }
    it "RRAS has Internet" -Tag "RRASInternet" {
        get-rrasvminternet -spath $PSScriptRoot | should -Be $true
    }
}
#endregion

#region ENV
Describe 'Env' -Tag 'ENV' {
    it "ReferenceVHDX" -Tag "RefVHDX" {
        get-RefVHDXstate -spath $PSScriptRoot | should -be $true
    }
    it 'Internet VSwitch should exist' -Tag "ExternalSwitch" { 
        get-ExternalSwitch | should -be $true 
    }
    it "Lab vSwitch should exist" -Tag "LabSwitch" {
        get-labswitch -spath $PSScriptRoot | should -be $true
    }
}
#endregion

#region DC
describe "DC" -Tag "DC" {
    it 'DC VHDX Should Exist' -Tag "DCVHDX" { 
        get-dcvhdxstate -spath $PSScriptRoot | should -be $true 
    }
    it "DC Should Exist" -Tag "DCVM" { 
        get-dcvmexists -spath $PSScriptRoot | should -be 1 
    }
    it "DC Should be running" -Tag "DCRunning" { 
        get-dcvmrunning -spath $PSScriptRoot | should -be 1 
    } 
    it "DC IP Set correctly" -Tag "DCIP" { 
        get-DCVMIP -spath $PSScriptRoot | should -be $true
    }
    it 'DC Domain Services Installed' -Tag "DCFeatures" {
        get-dcvmfeature -spath $PSScriptRoot | should -be $true
    }
    it 'DC has access to Internet' -Tag "DCInternet" {
        get-DCVMInternet -spath $PSScriptRoot | should -be $true
    }
    it "DC is promoted" -Tag "DCPromo" {
        get-DCVMPromoted -spath $PSScriptRoot | should -be $true
    }
    it "DC DHCP Scope enabled" -Tag "DCDHCP" {
        get-DCVMDHCPScope -spath $PSScriptRoot | should -be $true
    }
    it "DC CM Servers Group exists" -Tag "DCCM" {
        Get-DCVMCMGroupExists -spath $PSScriptRoot | should -be $true
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