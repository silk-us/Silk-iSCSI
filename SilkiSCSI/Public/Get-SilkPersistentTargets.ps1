function Get-SilkPersistentTargets {
    # needed for -Verbose to bind, without it the switch just lands in $args
    [CmdletBinding()]
    param(
        [string] $nodeAddress,
        [ipaddress] $cnodeIP
    )

    $regPath = Find-SilkiSCSIRegistryInstance
    $ipString = $cnodeIP.IPAddressToString

    if (-not $regPath) {
        Write-Error "SilkiSCSI registry instance not found."
        return
    }

    $regPath = $regPath + "\PersistentTargets"

    $targets = $targets = Get-ChildItem -Path $regPath

    $targetArray = @()

    foreach ($t in $targets) {
        # NOT $cnodeIP, thats the parameter and the loop would eat it
        $foundIP = $null
        $localIP = $null

        # open the subkey off the key object, the iqn in the key name has a colon in
        # it and powershell reads that as a drive qualifier if you rebuild the path
        $sub = $null
        try { $sub = $t.OpenSubKey('LoginTarget') } catch { }

        if ($sub) {
            # LocalIPAddress is a sockaddr_in - 02 00 <port> <4 byte ip>. thats our own
            # side of the login, we read it so we can rule it out below
            $lb = $sub.GetValue('LocalIPAddress')
            if ($lb -and $lb.Count -ge 8 -and $lb[0] -eq 2 -and $lb[1] -eq 0) {
                $localIP = Convert-SilkByteToIP -bytes $lb -offset 4
            }

            # LoginTargetIN isnt a sockaddr, its a struct with the cnode sat at byte 52
            # as 4 raw octets, right after an 01 00 00 00 marker at 48
            $tb = $sub.GetValue('LoginTargetIN')
            if ($tb -and $tb.Count -ge 56) {

                $candidate = Convert-SilkByteToIP -bytes $tb -offset 52
                if ($candidate -and $candidate -ne $localIP) {
                    $foundIP = $candidate
                    Write-Verbose "$($t.PSChildName) -> cnodeIP $foundIP (offset 52)"
                }

                # offset moved on us, hunt the 01 00 00 00 marker instead
                if (-not $foundIP) {
                    for ($i = 0; $i -le ($tb.Count - 8); $i++) {
                        if ($tb[$i] -ne 1 -or $tb[$i+1] -ne 0 -or $tb[$i+2] -ne 0 -or $tb[$i+3] -ne 0) { continue }
                        $candidate = Convert-SilkByteToIP -bytes $tb -offset ($i + 4)
                        if (-not $candidate -or $candidate -eq $localIP) { continue }
                        $foundIP = $candidate
                        Write-Verbose "$($t.PSChildName) -> cnodeIP $foundIP (marker at $i)"
                        break
                    }
                }

                if (-not $foundIP) {
                    $hex = ($tb | Select-Object -First 64 | ForEach-Object { $_.ToString('X2') }) -join ' '
                    Write-Verbose "$($t.PSChildName) -> no cnode found in $($tb.Count) bytes: $hex"
                }
            }

            $sub.Close()
        } else {
            Write-Verbose "$($t.PSChildName) -> no LoginTarget subkey"
        }

        $o = New-Object psobject 
        $o | Add-Member -MemberType NoteProperty -Name "Name" -Value $t.PSChildName
        $o | Add-Member -MemberType NoteProperty -Name "cnodeIP" -Value $foundIP
        $o | Add-Member -MemberType NoteProperty -Name "PSPath" -Value $t.name
        $targetArray += $o
    }

    if ($nodeAddress) {
        $targetArray = $targetArray | Where-Object { $_.name -like "$nodeAddress*" }
    } 

    if ($ipString) {
        $targetArray = $targetArray | Where-Object {$_.cnodeIP -eq $ipString}
    }
    return $targetArray

}
