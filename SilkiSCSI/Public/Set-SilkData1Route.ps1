function Set-SilkData1Route {
    <#
    .SYNOPSIS
        Works out the host side static route to an SDP's data1 subnet, and optionallyn sets it. Returns the inverse route the SDP needs.

    .PARAMETER data1Subnet
        The SDP's data1 CIDR summary, e.g. 10.10.0.128/28

    .PARAMETER interface
        Interface name to actually set the route on. Matches the alias from
        Get-NetIPAddress, and is forgiving about the space in "Ethernet 2".

    .PARAMETER force
        ADd the route even when one for this destination already exists on the interface.

    .EXAMPLE
        Set-SilkData1Route -data1Subnet 10.10.0.128/28

        Name       Destination      Gateway
        ----       -----------      -------
        Ethernet 2 10.10.0.128/28   10.30.0.1

    .EXAMPLE
        Set-SilkData1Route -data1Subnet 10.10.0.128/28 -Interface Ethernet2

    .EXAMPLE
        Run it with -Verbose to see every query, what came back, and the exact commands issued.

        Set-SilkData1Route -data1Subnet 10.10.0.128/28 -Interface Ethernet2 -Verbose
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $data1Subnet,
        [Parameter()]
        [string] $interface,
        [Parameter()]
        [switch] $force
    )

    Write-Verbose "=== Set-SilkData1Route ==="
    Write-Verbose "[input] data1Subnet = $data1Subnet"
    Write-Verbose "[input]$interface      = $(if ($interface) { $interface } else { '(none, listing only)' })"
    Write-Verbose "[input] force       = $force"

    # -- parse the data1 subnet ------------------------------------------------
    Write-Verbose "[calc]  Get-SilkSubnetInfo -subnet '$data1Subnet'"
    $data1 = Get-SilkSubnetInfo -subnet $data1Subnet
    if (!$data1) { return }

    Write-Verbose "[result] data1 network      : $($data1.Network)"
    Write-Verbose "[result] data1 mask         : $($data1.Mask)"
    Write-Verbose "[result] data1 prefix       : /$($data1.PrefixLength)"
    Write-Verbose "[result] data1 first usable : $($data1.FirstUsable)  <- the SDP side next hop"

    if ($data1.Cidr -ne $data1Subnet.Trim()) {
        Write-Verbose "[calc]  normalized '$($data1Subnet.Trim())' to '$($data1.Cidr)' (host address given, not the network)"
    }

    # -- which nics already have a default route -------------------------------
    # a default route means the nic is already routable, skip it. same rule the
    # FCA route dialog uses to decide what's eligible
    Write-Verbose "[query] Get-NetRoute -DestinationPrefix '0.0.0.0/0'"
    $defaultRoutes = @(Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue)
    foreach ($r in $defaultRoutes) {
        Write-Verbose "[result]  default route via $($r.NextHop) on ifIndex $($r.ifIndex) ($($r.InterfaceAlias))"
    }
    $defaultIndexes = @($defaultRoutes | Select-Object -ExpandProperty ifIndex -Unique)
    Write-Verbose "[result] primary ifIndexes  : $(if ($defaultIndexes.Count) { $defaultIndexes -join ', ' } else { '(none)' })"

    # -- which nics are actually up --------------------------------------------
    Write-Verbose "[query] Get-NetIPInterface -AddressFamily IPv4 | where ConnectionState -eq Connected"
    $interfaces = @(Get-NetIPInterface -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.ConnectionState -eq 'Connected' })
    foreach ($i in $interfaces) {
        Write-Verbose "[result]  connected ifIndex $($i.ifIndex) ($($i.InterfaceAlias)) metric $($i.InterfaceMetric)"
    }
    $connectedIndexes = @($interfaces | Select-Object -ExpandProperty ifIndex)

    # -- enumerate addresses ---------------------------------------------------
    Write-Verbose "[query] Get-NetIPAddress -AddressFamily IPv4"
    $allAddresses = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue)
    Write-Verbose "[result] $($allAddresses.Count) IPv4 address(es) on this host"
    foreach ($a in $allAddresses) {
        Write-Verbose "[result]  $($a.IPAddress)/$($a.PrefixLength) on ifIndex $($a.InterfaceIndex) ($($a.InterfaceAlias))"
    }

    $addresses = $allAddresses |
        Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' }

    $candidates = @()
    foreach ($a in $addresses) {
        if ($defaultIndexes -contains $a.InterfaceIndex) {
            Write-Verbose "[skip]  $($a.InterfaceAlias) ($($a.IPAddress)) holds a default route, already routable"
            continue
        }
        if ($connectedIndexes -notcontains $a.InterfaceIndex) {
            Write-Verbose "[skip]  $($a.InterfaceAlias) ($($a.IPAddress)) is not connected"
            continue
        }

        Write-Verbose "[calc]  Get-SilkSubnetInfo -subnet '$($a.IPAddress)/$($a.PrefixLength)'"
        $nic = Get-SilkSubnetInfo -subnet "$($a.IPAddress)/$($a.PrefixLength)" -ErrorAction SilentlyContinue
        if (!$nic) {
            Write-Verbose "[skip]  $($a.InterfaceAlias) subnet math failed"
            continue
        }
        Write-Verbose "[result]  $($a.InterfaceAlias) subnet $($nic.Cidr), inferred gateway $($nic.FirstUsable) (network + 1)"

        $row = New-Object psobject
        $row | Add-Member -MemberType NoteProperty -Name Name -Value $a.InterfaceAlias
        $row | Add-Member -MemberType NoteProperty -Name Destination -Value $data1.Cidr
        $row | Add-Member -MemberType NoteProperty -Name Gateway -Value $nic.FirstUsable
        $row | Add-Member -MemberType NoteProperty -Name InterfaceIndex -Value $a.InterfaceIndex
        $row | Add-Member -MemberType NoteProperty -Name InterfaceAddress -Value "$($a.IPAddress)/$($a.PrefixLength)"
        $candidates += $row
    }

    Write-Verbose "[result] $($candidates.Count) eligible secondary interface(s): $(if ($candidates.Count) { ($candidates.Name -join ', ') } else { '(none)' })"

    if ($candidates.Count -eq 0) {
        Write-Warning "No secondary interfaces found. Every connected nic holds a default route, so no static route is needed."
        return
    }

    # no -interface), just show what we found
    if (!$interface) {
        Write-Verbose "[done]  no -Interface given, returning the candidate table without changing anything"
        return $candidates
    }

    # -- pick the interface ----------------------------------------------------
    Write-Verbose "[calc]  matching -Interface '$interface' against interface names"
    $target = $candidates | Where-Object { $_.Name -eq $interface } | Select-Object -First 1
    if ($target) {
        Write-Verbose "[result] exact name match on '$($target.Name)'"
    } else {
        # tolerate Ethernet2 for "Ethernet 2", thats how everyone types it
        $squashed = $interface -replace '\s', ''
        Write-Verbose "[calc]  no exact match, retrying whitespace-insensitive against '$squashed'"
        $target = $candidates | Where-Object { ($_.Name -replace '\s', '') -eq $squashed } | Select-Object -First 1
        if ($target) {
            Write-Verbose "[result] matched '$($target.Name)' ignoring whitespace"
        }
    }
    if (!$target) {
        Write-Error "No eligible interface named '$interface'. Run without -Interface to see the candidates."
        return
    }

    Write-Verbose "[result] target interface   : $($target.Name)"
    Write-Verbose "[result] target ifIndex     : $($target.InterfaceIndex)"
    Write-Verbose "[result] target address     : $($target.InterfaceAddress)"
    Write-Verbose "[result] route destination  : $($target.Destination)"
    Write-Verbose "[result] route next hop     : $($target.Gateway)"

    # -- already there? --------------------------------------------------------
    Write-Verbose "[query] Get-NetRoute -DestinationPrefix $($data1.Cidr) -InterfaceIndex $($target.InterfaceIndex)"
    $routeAdded = $false
    $existing = @(Get-NetRoute -DestinationPrefix $data1.Cidr -InterfaceIndex $target.InterfaceIndex -ErrorAction SilentlyContinue)
    foreach ($e in $existing) {
        Write-Verbose "[result]  existing route via $($e.NextHop), store $($e.Store), metric $($e.RouteMetric)"
    }
    if ($existing.Count -eq 0) {
        Write-Verbose "[result] no existing route for this destination on this interface"
    }

    if ($existing.Count -gt 0 -and !$force) {
        Write-Verbose "[skip]  route exists and -force was not given, leaving it alone"
        Write-Warning "A route to $($data1.Cidr) already exists on $($target.Name). Use -force to add it anyway."
    } else {
        if ($existing.Count -gt 0) {
            Write-Verbose "[calc]  route exists but -force given, adding anyway"
        }

        $routeSplat = @{
            DestinationPrefix = $data1.Cidr
            InterfaceIndex    = $target.InterfaceIndex
            NextHop           = $target.Gateway
        }
        Write-Verbose "[command] New-NetRoute -DestinationPrefix $($data1.Cidr) -InterfaceIndex $($target.InterfaceIndex) -NextHop $($target.Gateway)"
        try {
            $added = New-NetRoute @routeSplat -ErrorAction Stop
            foreach ($n in @($added)) {
                Write-Verbose "[result]  created $($n.DestinationPrefix) via $($n.NextHop) on ifIndex $($n.ifIndex), store $($n.Store), metric $($n.RouteMetric)"
            }
            $routeAdded = $true
        } catch {
            Write-Verbose "[result] New-NetRoute threw: $($_.Exception.GetType().Name)"
            Write-Error "Failed to add the route: $($_.Exception.Message)"
            return
        }
    }

    # New-NetRoute doesnt always land in the persistent store, and a route that
    # doesnt survive a reboot is worse than no route at all. check and say so
    Write-Verbose "[query] Get-NetRoute -DestinationPrefix $($data1.Cidr) -InterfaceIndex $($target.InterfaceIndex) -PolicyStore PersistentStore"
    $persisted = @(Get-NetRoute -DestinationPrefix $data1.Cidr -InterfaceIndex $target.InterfaceIndex `
        -PolicyStore PersistentStore -ErrorAction SilentlyContinue)
    foreach ($p in $persisted) {
        Write-Verbose "[result]  persistent entry via $($p.NextHop) on ifIndex $($p.ifIndex), survives reboot"
    }
    $persistent = $persisted.Count -gt 0
    if (!$persistent) {
        Write-Verbose "[result] nothing in the persistent store for this destination"
        Write-Warning "The route is active but is not in the persistent store, so it will not survive a reboot. Add it again with -PolicyStore PersistentStore, or use 'route add $($data1.Network) MASK $($data1.Mask) $($target.Gateway) -p'."
    }

    # -- the SDP side ----------------------------------------------------------
    Write-Verbose "[calc]  Get-SilkData1InverseRoute -data1Subnet $($data1.Cidr) -hostSubnet $($target.InterfaceAddress)"
    $inverse = Get-SilkData1InverseRoute -data1Subnet $data1.Cidr -hostSubnet $target.InterfaceAddress
    if (!$inverse) { return }

    Write-Verbose "[result] inverse destination : $($inverse.Destination) (the $($target.Name) subnet)"
    Write-Verbose "[result] inverse mask        : $($inverse.DestinationMask)"
    Write-Verbose "[result] inverse gateway     : $($inverse.Gateway) (first usable on data1)"

    $return = New-Object psobject
    $return | Add-Member -MemberType NoteProperty -Name Name -Value $target.Name
    $return | Add-Member -MemberType NoteProperty -Name InterfaceIndex -Value $target.InterfaceIndex
    $return | Add-Member -MemberType NoteProperty -Name Destination -Value $target.Destination
    $return | Add-Member -MemberType NoteProperty -Name Gateway -Value $target.Gateway
    $return | Add-Member -MemberType NoteProperty -Name RouteAdded -Value $routeAdded
    $return | Add-Member -MemberType NoteProperty -Name Persistent -Value $persistent
    $return | Add-Member -MemberType NoteProperty -Name InverseDestination -Value $inverse.Destination
    $return | Add-Member -MemberType NoteProperty -Name InverseDestinationMask -Value $inverse.DestinationMask
    $return | Add-Member -MemberType NoteProperty -Name InverseGateway -Value $inverse.Gateway
    return $return
}
