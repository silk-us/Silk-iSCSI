# Silk iSCSI Services Connection Module (SISCM)
This module is a wrapper for the native iSCSI and MPIO powershell modules, created to help ease the management connections and sessions to Silk SDP CNodes.

### Installation
Manually install
```powershell
Import-Module ./path/SilkiSCSI/SilkiSCSI.psd1
```

Or install via the PowerShell Gallery
```powershell
Find-Module SilkiSCSI | Install-Module -Confirm:$false
```

Or, run the provided InstallSilkiSCSI.ps1 script.
```powershell
Unblock-File .\InstallSilkiSCSI.ps1
.\InstallSilkiSCSI.ps1
```
Which gives you a simple install menu.
```powershell
------
1. C:\Users\user\Documents\PowerShell\Modules
2. C:\Program Files\PowerShell\Modules
3. c:\program files\powershell\7\Modules
4. C:\Program Files (x86)\WindowsPowerShell\Modules
5. C:\WINDOWS\system32\WindowsPowerShell\v1.0\Modules
------
Select Install location:
```

### Example usage:
Please see the [Command Refence](./Documents/Command_Reference.md) for a full explanation of the exported commands.


