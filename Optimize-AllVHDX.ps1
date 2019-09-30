$vms = get-vm
foreach ($vm in $vms) {
    if ($vm.state -eq "off") {
        foreach ($disk in $vm.harddrives) {
            Optimize-VHD -Path $disk.path -Mode Full
        }
    }
}