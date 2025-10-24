function Remove-SilkSDP {
    [CmdletBinding(DefaultParameterSetName="nodeAddress")]

    param(
        [Parameter(ParameterSetName="nodeAddress")]
        [string] $nodeAddress,

        [Parameter(ParameterSetName="All")]
        [switch] $All
    )

    if ($All) {
        $allsessions = Get-SilkSessions
    }
    else {
        if (!$nodeAddress) {
            $nodeSelect = Select-SilkSDP -message "Please select the correct node address to remove entirely" -force
            $nodeAddress = $nodeSelect.NodeAddress
        }
        $allsessions = Get-SilkSessions | Where-Object {$_.'Silk IQN' -eq $nodeaddress}
    }

    # output sessions to be removed
    Write-Host "Sessions to be removed:"
    $allsessions | Format-Table

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