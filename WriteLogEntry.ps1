
function Write-LogEntry {
    [cmdletBinding()]
    param (
        [ValidateSet("Information", "Error")]
        $Type = "Information",
        [parameter(Mandatory = $true)]
        $Message
    )
    switch ($Type) {
        'Error' {
            $Severity = 3
            break;
        }
        'Information' {
            $Severity = 6
            break;
        }
    }
    $DateTime = New-Object -ComObject WbemScripting.SWbemDateTime
    $DateTime.SetVarDate($(Get-Date))
    $UtcValue = $DateTime.Value
    $UtcOffset = $UtcValue.Substring(21, $UtcValue.Length - 21)
    $scriptname = (Get-PSCallStack)[1]
    $logline = `
        "<![LOG[$message]LOG]!>" + `
        "<time=`"$(Get-Date -Format HH:mm:ss.fff)$($UtcOffset)`" " + `
        "date=`"$(Get-Date -Format M-d-yyyy)`" " + `
        "component=`"$($scriptname.Command)`" " + `
        "context=`"$([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)`" " + `
        "type=`"$Severity`" " + `
        "thread=`"$PID`" " + `
        "file=`"$($Scriptname.ScriptName)`">";
        
    $logline | Out-File -Append -Encoding utf8 -FilePath $Logfile -Force
    Write-Verbose $Message
}