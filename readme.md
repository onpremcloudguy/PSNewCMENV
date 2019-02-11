# SCCM Lab Environment PowerShell script #

This script has been a few months in the making, I created it for 2 reasons in order.

> 1. To learn how to use Pester in PowerShell,
> 2. Build multiple Isolated SCCM labs for testing using a single external IP address (RRAS Server)

As a result of the script being written to learn Pester it doesn't always use the cleanest code to build the servers for the SCCM environment.

The solution is designed to run on a Hyper-V host and provision the following virtual machines

> - RRAS (one per Hyper-V host)
> - Domain Controller (one per environment)
> - SCCM Server (one per environment)
> - Certificate Authority (one per environment)

To complete this task I'm using PowerShell Direct so there is a requirement to use either Windows 10 or Server 2016 at the host OS for the solution.

the solution was developed on a higher end laptop so it does have some high number for RAM on each of the devices update as suits your lab hardware.

## Instructions ##

Update the env.json file to reflect the location for SQL, ADK, SCCM, Windows Server 2016 & the Sources directory for .Net 3.5 installation media for Server 2016.

The script has been setup to use either TP or Production version of SCCM, and you can see in the code where this is handled.

Execute LabTest.ps1 to spin up a Lab.

### Known issues ###

CM System Discovery setting does't auto configure.

Tweet me on @onpremcloudguy if there are anything you think should be included.

big thanks to @ncbrady from @windowsnoob, and the Guys & Girls from @SCConfigMgr for there previous work in documenting the installation of SCCM and the dependent components.