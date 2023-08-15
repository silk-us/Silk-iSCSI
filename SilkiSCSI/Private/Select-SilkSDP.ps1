function Select-SilkSDP {
    param(
        [parameter()]
        [string] $nodeAddress,
        [parameter()]
        [switch] $force,
        [parameter()]
        [string] $message = 'Select the SDP From the list'
    )
    Start-Sleep -Seconds 1

    Write-Verbose '>> Invoking Select-SilkSDP'

    if ($nodeAddress) {
        $SDPIQN = Get-IscsiTarget -NodeAddress $nodeAddress | Where-Object {$_.NodeAddress -match "kaminario" -or $_.NodeAddress -match "silk"} | Sort-Object NodeAddress -Unique
    } else {
        $SDPIQN = Get-IscsiTarget | Where-Object {$_.NodeAddress -match "kaminario" -or $_.NodeAddress -match "silk"} | Sort-Object NodeAddress -Unique

    }
    if ($SDPIQN) {
        $count = ($SDPIQN.NodeAddress | Measure-Object).count
    } else {
        $count = 0
    }
    
    if ($count -gt 1 -or $force) {
        Write-Verbose '>> Greater than 1 SDP detected, producing selection menu... '

        $SDP = Build-MenuFromArray -array $SDPIQN -property NodeAddress -message $message
        $returnSDP = $SDPIQN | Where-Object {$_.Nodeaddress -eq $SDP}
        return $returnSDP
    } elseif ($count -eq 1) {
        Write-Verbose '>> 1 SDP detected, skipping selection menu... '

        $returnSDP = $SDPIQN 
        return $returnSDP
    } else {
        return $null
    }
}