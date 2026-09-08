# Silk-iSCSI Command Reference. 

## Get-SilkSessions
This simply queries for any existing Silk SDP sessions configured on the windows host. Even if those sessions were not configuring using the Silk-iSCSI module. Pipe it to `Format-Table` (`ft`) for better readability. 
* `-cnodeIP`: (Optional) [string] The IP for a specific CNode. This will return only the connection information for the specified CNode. 
* `-nodeAddress`: (Optional) [string] The iqn of a specific Silk SDP. Useful in cases where the host is connected to multiple SDPs. 
* `-update`: (Optional) [switch] Forces an Update-MPIOClaimedHW "rescan" of the device list. This can be useful when accounting for recent disk changes. 
* `-totalOnly`: (Optional) [switch] This returns a consolodated tally that includes a total number of sessions only. Primarily used for programatic queries. 

 ### Example:
```PowerShell 
Get-SilkSessions | ft

CNode IP     Host IP   Configured Sessions Connected Sessions Silk IQN
--------     -------   ------------------- ------------------ --------
10.10.10.132 10.12.1.6                  12                 12 iqn.2009-01.us.silk:storage.sdp.12345602
10.10.10.133 10.12.1.6                  12                 12 iqn.2009-01.us.silk:storage.sdp.12345602
```

## Connect-SilkCnode
This command connects a specified number of sessions to a specified CNode. 

* `-cnodeIP`: (Required) [string] Specifies the IP Address of the Silk SDP CNode you wish to connect to. 
* `-sessionCount`: (Optional / default:`1`) [int] Specify the number of sessions to connect to the specified CNode.
* `-nodeAddress`: (Optional) [string] The iqn of a specific Silk SDP. Required in cases where the host is connected to multiple SDPs. 
* `-rebalance`: (Optional) [switch] Automatically refactor the sessions so they maintain the current total session count.

### Example:
Connect 12 sessions to existing silk CNodes. 
```PowerShell
Connect-SilkCnode -cnodeIP 10.10.10.132 -SessionCount 12
Connect-SilkCnode -cnodeIP 10.10.10.133 -SessionCount 12
 ```
### Example:
Connect a new cnode and re-balance the sessions by specifying `-rebalance`. So if there are 2 cnodes with 24 sessions, this will connect a 3rd cnode and re-balance the session count to 8 per cnode. 
```PowerShell 
Connect-SilkCnode -cnodeIP 10.10.10.134 -rebalance
```
### Example:
Specifying `-nodeAddress` will connect to a cnode where there are multiple Silk SDPs (or other iscsi targets) already connected. 
```PowerShell 
Connect-SilkCnode -cnodeIP 10.10.10.134 -nodeAddress 'iqn.2009-01.us.silk:storage.sdp.12345602'
```

## Disconnect-SilkCNode
Disconnect a Silk CNode and all of its sessions. You cannot specify a specific number of sessions, it will remove all sessions. 
* `-cnodeIP`: (Required) [string] Specifies the IP Address of the Silk SDP CNode you wish to connect to. 
* `-rebalance`: (Optional) [switch] Automatically refactor the sessions so they maintain the current total session count.
* `-force`: (Optional) [switch] Attempts to more-forcibly remove session information as it pertains to the specified CNode. Useful when trying to remove orphaned iscsi sessions. *May be disruptive*. 


### Example:
```PowerShell
Disconnect-SilkCnode -cnodeIP 10.10.10.134
```
### Example:
Specify `-rebalance` to have the command automatically refactor the sessions so they maintain the total session count. So, if there are 3 CNodes with 8 sessions per for a total of 24 sessions, specifying `-rebalance` will remove the specified cnode and then add the appropriate number of sessions to the remaining 2 cnodes to (in this example) 12 per. 
```PowerShell
Disconnect-SilkCnode -cnodeIP 10.10.10.134 -rebalance
```
### Example:
You can specify `-force` to more forcibly remove orpaned iSCSI sessions. This does invoke an Update-MPIOClaimedHW which can sometimes disrupt IO on any MPIO claimed devices, so this is best used when troubleshooting. 
```PowerShell
Disconnect-SilkCnode -cnodeIP 10.10.10.134 -force
```

## Set-SilkSessionBalance
This command will simply refactor all Silk SDP sessions. Regardless of their current session count.
* `-sessionsPer`: (Optional) [int] The number of sessions per Silk CNode to be configured. If not specified it divide the total current sessions (rounding up) and provision that number per CNode. 
* `-nodeAddress`: (Optional) [string] The iqn of a specific Silk SDP. Required in cases where the host is connected to multiple SDPs. 

### Example:
```PowerShell 
Get-SilkSessions | ft

CNode IP     Host IP   Configured Sessions Connected Sessions Silk IQN
--------     -------   ------------------- ------------------ --------
10.10.10.132 10.12.1.6                   9                  9 iqn.2009-01.us.silk:storage.sdp.12345602
10.10.10.133 10.12.1.6                   8                  8 iqn.2009-01.us.silk:storage.sdp.12345602
10.10.10.134 10.12.1.6                   1                  1 iqn.2009-01.us.silk:storage.sdp.12345602

Set-SilkSessionBalance -sessionsPer 8

CNode IP     Host IP   Configured Sessions Connected Sessions Silk IQN
--------     -------   ------------------- ------------------ --------
10.10.10.132 10.12.1.6                   8                  8 iqn.2009-01.us.silk:storage.sdp.12345602
10.10.10.133 10.12.1.6                   8                  8 iqn.2009-01.us.silk:storage.sdp.12345602
10.10.10.134 10.12.1.6                   8                  8 iqn.2009-01.us.silk:storage.sdp.12345602
```
### Example:
This command similarly supports `-nodeAddress`
```PowerShell
Set-SilkSessionBalance -sessionsPer 8 -nodeAddress 'iqn.2009-01.us.silk:storage.sdp.12345602'
```

## Remove-SilkSDP
This command will remove all connection information for a specified Silk SDP.
* `-nodeAddress`: (Optional) [string] The iqn of a specific Silk SDP. Required in cases where the host is connected to multiple SDPs. 

### Example
```PowerShell
Remove-SilkSDP -nodeAddress 'iqn.2009-01.us.silk:storage.sdp.12345602'
```

## Set-SilkData1Route
Works out the host side static route to an SDP's data1 subnet, and optionally sets it. The module doesn't talk to Flex, so you have to hand it the data1 CIDR yourself. Any interface holding a default route is skipped, those are already routable and don't need a static route. What's left is every secondary NIC, with the gateway inferred as the first usable address on that NIC's own subnet.

Run it without `-interface` and it just returns the candidates so you can look them over. Run it with `-interface` and it adds the route with `New-NetRoute`, then returns the inverse route you need to configure on the SDP side.
* `-data1Subnet`: (Required) [string] The SDP's data1 CIDR summary, e.g. `10.10.0.128/28`. A host address works too, it gets normalized to the network address.
* `-interface`: (Optional) [string] The interface to actually set the route on. Matches the alias from `Get-NetIPAddress`, and is forgiving about the space in "Ethernet 2".
* `-force`: (Optional) [switch] Add the route even when one for this destination already exists on that interface.

### Example:
With no `-interface` this only reports, it doesn't change anything.
```PowerShell
Set-SilkData1Route -data1Subnet 10.10.0.128/28

Name       Destination    Gateway
----       -----------    -------
Ethernet 2 10.10.0.128/28 10.30.0.1
```
### Example:
Specifying `-interface` sets the route and returns the inverse route for the SDP.
```PowerShell
Set-SilkData1Route -data1Subnet 10.10.0.128/28 -interface Ethernet2

Name                   : Ethernet 2
InterfaceIndex         : 7
Destination            : 10.10.0.128/28
Gateway                : 10.30.0.1
RouteAdded             : True
Persistent             : True
InverseDestination     : 10.30.0.0
InverseDestinationMask : 255.255.255.0
InverseGateway         : 10.10.0.129
```
The `Inverse*` values are the route that has to exist on the SDP so traffic can find its way back to the host. `Persistent` tells you whether the route landed in the persistent store, if it comes back `False` the route won't survive a reboot.

## Get-SilkPersistentTargets
Lists the persistent (favorite) iSCSI targets Windows keeps in the registry. These are written one per persistent login and disconnecting a session does not remove them, so they pile up over time and get logged in again every time the MSiSCSI service starts.
* `-nodeAddress`: (Optional) [string] The iqn of a specific Silk SDP. Returns only the targets whose key name starts with this.
* `-cnodeIP`: (Optional) [string] The IP for a specific CNode. Returns only the targets logged in against that CNode.

### Example:
```PowerShell
Get-SilkPersistentTargets | ft Name, cnodeIP

Name                                                       cnodeIP
----                                                       -------
iqn.2009-01.us.silk:storage.sdp.12345602#0x0FE0DFA4CE3FDD01 10.10.10.132
iqn.2009-01.us.silk:storage.sdp.12345602#0x147AA8A4CE3FDD01 10.10.10.132
iqn.2009-01.us.silk:storage.sdp.12345602#0x214A9AA4CE3FDD01 10.10.10.133
```
### Example:
Narrow it down to one CNode.
```PowerShell
Get-SilkPersistentTargets -cnodeIP 10.10.10.132
```

## Remove-SilkPersistentTarget
Removes a persistent target from the registry. There is no native cmdlet for this once the session behind it is gone, `Unregister-IscsiSession` only works while the session still exists, so anything orphaned has to come out of the registry directly. Takes its input from the pipeline, so pair it with `Get-SilkPersistentTargets`.
* `-target`: (Required) [object] A target object from `Get-SilkPersistentTargets`. Accepts pipeline input.

### Example:
Clear the leftovers for one CNode.
```PowerShell
Get-SilkPersistentTargets -cnodeIP 10.10.10.132 | Remove-SilkPersistentTarget
```
### Example:
Clear everything for one SDP.
```PowerShell
Get-SilkPersistentTargets -nodeAddress 'iqn.2009-01.us.silk:storage.sdp.12345602' | Remove-SilkPersistentTarget
```
Restart the MSiSCSI service afterwards so the initiator re-reads the list, otherwise it will still be working from what it cached at startup.

## A note on using `-verbose`

As this module is primarily a wrapper for the native Microsoft iSCSI powershell cmdlets, Specifying `-verbose` on any command will show you the underlying commands that are being issued. 