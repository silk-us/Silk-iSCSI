function Get-SilkSubnetInfo {
    <#
    .SYNOPSIS
        Subnet math for an IPv4 CIDR. Returns the network address, dotted mask and
        the first usable host.

    .DESCRIPTION
        Shared by Set-SilkData1Route and Get-SilkData1InverseRoute. Works on a byte
        array rather than shifting a uint32 so it behaves the same on 5.1 and 7.

        The address does not have to be the network address, a host address in the
        subnet works fine and gets normalized.

    .EXAMPLE
        Get-SilkSubnetInfo -subnet 10.10.0.130/28
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $subnet
    )

    $parts = $subnet.Trim() -split '/'
    if ($parts.Count -ne 2) {
        Write-Error "Subnet '$subnet' is not CIDR notation. Expecting something like 10.10.0.128/28"
        return
    }

    $prefix = 0
    if (-not [int]::TryParse($parts[1], [ref]$prefix) -or $prefix -lt 0 -or $prefix -gt 32) {
        Write-Error "Prefix length '$($parts[1])' is not valid, must be 0-32"
        return
    }

    try {
        $ip = [System.Net.IPAddress]::Parse($parts[0])
    } catch {
        Write-Error "'$($parts[0])' is not a valid IP address"
        return
    }
    if ($ip.AddressFamily -ne 'InterNetwork') {
        Write-Error "'$($parts[0])' is not IPv4"
        return
    }

    # mask one octet at a time. bits left for this octet, clamped to 0-8
    $ipBytes = $ip.GetAddressBytes()
    $maskBytes = New-Object byte[] 4
    $netBytes = New-Object byte[] 4
    for ($i = 0; $i -lt 4; $i++) {
        $bits = [math]::Min(8, [math]::Max(0, $prefix - ($i * 8)))
        $maskBytes[$i] = [byte](256 - [math]::Pow(2, 8 - $bits))
        $netBytes[$i] = [byte]($ipBytes[$i] -band $maskBytes[$i])
    }

    # network + 1, with carry so a /31 or /32 doesnt roll off the end
    $firstBytes = $netBytes.Clone()
    for ($i = 3; $i -ge 0; $i--) {
        if ($firstBytes[$i] -lt 255) {
            $firstBytes[$i] = [byte]($firstBytes[$i] + 1)
            break
        }
        $firstBytes[$i] = [byte]0
    }

    $network = ($netBytes | ForEach-Object { $_ }) -join '.'
    $mask = ($maskBytes | ForEach-Object { $_ }) -join '.'
    $first = ($firstBytes | ForEach-Object { $_ }) -join '.'

    $return = New-Object psobject
    $return | Add-Member -MemberType NoteProperty -Name Network -Value $network
    $return | Add-Member -MemberType NoteProperty -Name PrefixLength -Value $prefix
    $return | Add-Member -MemberType NoteProperty -Name Mask -Value $mask
    $return | Add-Member -MemberType NoteProperty -Name Cidr -Value "$network/$prefix"
    $return | Add-Member -MemberType NoteProperty -Name FirstUsable -Value $first
    return $return
}
