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

## A note on using `-verbose`

As this module is primarily a wrapper for the native Microsoft iSCSI powershell cmdlets, Specifying `-verbose` on any command will show you the underlying commands that are being issued. 