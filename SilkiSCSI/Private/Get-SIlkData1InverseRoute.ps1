function Get-SilkData1InverseRoute {
    <#
    .SYNOPSIS
        Works out the return route the SDP needs so traffic can get back to the host.

    .DESCRIPTION
        The host side route sends the data1 subnet out a secondary nic. The SDP needs
        the mirror of that: a route to the hosts own subnet, via the first usable
        address in its data1 subnet.

        So it flips around:
            host route     dest = data1 subnet      via = first usable on the nic subnet
            inverse route  dest = the nic subnet    via = first usable on data1

    .PARAMETER data1Subnet
        The SDP data1 CIDR, e.g. 10.10.0.128/28

    .PARAMETER hostSubnet
        The secondary nic's address and prefix, e.g. 10.40.3.17/24

    .EXAMPLE
        Get-SilkData1InverseRoute -data1Subnet 10.40.50.128/28 -hostSubnet 10.40.3.17/24
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $data1Subnet,

        [Parameter(Mandatory)]
        [string] $hostSubnet
    )

    $data1 = Get-SilkSubnetInfo -subnet $data1Subnet
    if (!$data1) { return }

    # not $host, thats the powershell console object
    $hostNet = Get-SilkSubnetInfo -subnet $hostSubnet
    if (!$hostNet) { return }

    $return = New-Object psobject
    $return | Add-Member -MemberType NoteProperty -Name Destination -Value $hostNet.Network
    $return | Add-Member -MemberType NoteProperty -Name DestinationMask -Value $hostNet.Mask
    $return | Add-Member -MemberType NoteProperty -Name Gateway -Value $data1.FirstUsable
    return $return
}
