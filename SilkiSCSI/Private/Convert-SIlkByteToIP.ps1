function Convert-SilkByteToIP {
    <#
    .SYNOPSIS
        Pulls 4 octets out of a byte array and returns them as a dotted IPv4 string.

    .DESCRIPTION
        The iSCSI initiator stores addresses as raw octets inside larger binary
        registry values, sometimes inside a sockaddr, sometimes just parked in a
        struct. This reads 4 bytes at an offset and sanity checks them so we dont
        hand back padding or a length field that happens to look like an address.

        Returns $null when the bytes arent a plausible unicast v4 address.

    .PARAMETER bytes
        The binary value to read from.

    .PARAMETER offset
        Where the 4 octets start. Defaults to 0.

    .EXAMPLE
        Convert-SilkByteToIP -bytes $loginTargetIN -offset 52

    .EXAMPLE
        # sockaddr_in, address sits after the family and port
        Convert-SilkByteToIP -bytes $localIPAddress -offset 4
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [byte[]] $bytes,

        [Parameter()]
        [int] $offset = 0
    )

    if ($offset -lt 0 -or ($offset + 3) -ge $bytes.Count) {
        Write-Verbose "offset $offset is outside a $($bytes.Count) byte value"
        return $null
    }

    $o1 = $bytes[$offset]
    $o2 = $bytes[$offset + 1]
    $o3 = $bytes[$offset + 2]
    $o4 = $bytes[$offset + 3]

    # 0.x, 127.x and anything above 223 arent cnodes
    if ($o1 -lt 1 -or $o1 -gt 223 -or $o1 -eq 127) {
        return $null
    }

    # a zero tail means we landed on padding or a small dword, not an address
    if ($o2 -eq 0 -and $o3 -eq 0 -and $o4 -eq 0) {
        return $null
    }

    return "$o1.$o2.$o3.$o4"
}
