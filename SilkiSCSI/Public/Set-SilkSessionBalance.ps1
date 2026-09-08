function Set-SilkSessionBalance {
    param(
        [parameter()]
        [int] $sessionsPer,
        [Parameter()]
        [string] $nodeAddress
    )

    if (!$nodeAddress) {
        $SDPIQN = Select-SilkSDP 
        $nodeAddress = $SDPIQN.NodeAddress
    } 
  
    Write-Verbose ">> Invoking - Set-SilkSessionBalance"

    $total = Get-SilkSessions -NodeAddress $nodeAddress -totalOnly
    $sessions = Get-SilkSessions -NodeAddress $nodeAddress | Sort-Object 'Connected Sessions' -Descending

    $currentSessions = $total.'Configured Sessions'
    $currentCnodes = $total.CNodes 
    
    if (!$sessionsPer) {
        $sessionsPer = Get-SilkSessionsPer -nodes $currentCnodes -sessions $currentSessions
        Write-Verbose "---- Dynamically determined - $sessionsPer - sessions per CNode"
    } else {
        Write-Verbose "---- Using - $sessionsPer - sessions per CNode"
    }

    foreach ($s in $sessions) {
        $nodeSessions = $s.'Configured Sessions'
        $cnodeIP = $s.'CNode IP'
        if ($nodeSessions -lt $sessionsPer) {
            $sessionCount = $sessionsPer - $nodeSessions
            Write-Verbose "---- Adding - $sessionCount - to CNode - $cnodeIP -"
            try {
                Connect-SilkCNode -SessionCount $sessionCount -cnodeIP $cnodeIP -NodeAddress $nodeAddress -ErrorAction Stop | Out-Null
            } catch {
                Write-Error "Could not add $sessionCount session(s) to CNode $cnodeIP - $($_.Exception.Message)"
            }
        } elseif ($nodeSessions -gt $sessionsPer) {
            Write-Verbose "---- Removing - $cnodeIP - and adding $sessionsPer"
            try {
                Disconnect-SilkCNode -cnodeIP $cnodeIP -ErrorAction Stop | Out-Null
                Connect-SilkCNode -cnodeIP $cnodeIP -SessionCount $sessionsPer -NodeAddress $nodeAddress -ErrorAction Stop | Out-Null
            } catch {
                Write-Error "Could not rebalance CNode $cnodeIP to $sessionsPer session(s) - $($_.Exception.Message)"
            }
        }
    }
}