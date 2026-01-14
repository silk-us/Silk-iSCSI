function Set-SilkQuickiSCSIRecovery {
    param(
        [parameter()]
        [switch] $setDefaults,
        [parameter()]
        [switch] $force
    )

    $regPath = Find-SilkiSCSIRegistryInstance

    $parameterPath = $regPath + '\Parameters'

    if (!$force) {  
        $silkSet = Get-ItemProperty -Path $parameterPath -Name 'silkQuickConnect' -ErrorAction SilentlyContinue
        if ($silkSet.silkQuickConnect -eq 1) {
            $doRun = $false
            Write-Verbose "silkQuickConnect is already set to 1. No changes will be made."
        } else {
            $doRun = $true
            Write-Verbose "silkQuickConnect is not set to 1. Changes will be made."
        }
    } else {
        $doRun = $true
    }

    if ($setDefaults) {
        $parameterSplat = @{
            'TCPConnectTime' = 15
            'TCPDisconnectTime' = 15
            'DelayBetweenReconnect' = 5
            'EnableNOPOut' = 'Disabled'
            'MaxRequestHoldTime' = 60
            'LinkDownTime' = 15
            'SrbTimeoutDelta' = 15
            'silkQuickConnect' = 0
        }
    } else {
        $parameterSplat = @{
            'TCPConnectTime' = 3
            'TCPDisconnectTime' = 3
            'DelayBetweenReconnect' = 3
            'EnableNOPOut' = 'Enabled'
            'MaxRequestHoldTime' = 10
            'LinkDownTime' = 3
            'SrbTimeoutDelta' = 3
            'silkQuickConnect' = 1
        }
    }

    if ($doRun -or $setDefaults) {
        Write-Verbose "Applying quick iSCSI recovery settings."
        foreach ($key in $parameterSplat.Keys) {
            Write-Verbose "-> Setting $key to $($parameterSplat[$key])"
            Set-ItemProperty -Path $parameterPath -Name $key -Value $parameterSplat[$key]
        }
    }
}





