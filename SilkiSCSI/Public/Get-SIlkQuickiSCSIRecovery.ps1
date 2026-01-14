function Get-SilkQuickiSCSIRecovery {
    $regPath = Find-SilkiSCSIRegistryInstance

    $parameterPath = $regPath + '\Parameters'

    $regSettings = $(
            'TCPConnectTime',
            'TCPDisconnectTime',
            'DelayBetweenReconnect',
            'EnableNOPOut',
            'MaxRequestHoldTime',
            'LinkDownTime',
            'SrbTimeoutDelta'
    )

    $settingArray = @{}
    foreach ($setting in $regSettings) {
        $value = Get-ItemProperty -Path $parameterPath -Name $setting -ErrorAction SilentlyContinue
        
        if ($value) {
            $settingArray[$setting] = $value.$setting
        }
    }
    return $settingArray 
}