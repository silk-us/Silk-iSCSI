function Remove-SilkSDP {
    param(
        [Parameter()]
        [string] $nodeAddress
    )

    if (!$nodeAddress) {
        $nodeSelect = Select-SilkSDP -message "Please select the correct node address to remote entirely" -force
        $nodeAddress = $nodeSelect.NodeAddress
    }
    $allsessions = Get-SilkSessions | Where-Object {$_.'Silk IQN' -eq $nodeaddress}

    if ($allsessions) {
        foreach ($i in $allsessions) {
            Disconnect-SilkCNode -cnodeIP $i.'CNode IP'
        }
    } else {
        $return = "No target with $nodeaddress discovered."
        return $return | Write-Error 
    }

    $return = Get-SilkSessions
    return $return 
} 