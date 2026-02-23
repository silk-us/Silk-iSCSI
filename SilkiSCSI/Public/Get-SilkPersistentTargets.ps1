function Get-SilkPersistentTargets {

    param(
        [string]$nodeAddress
    )

    $regPath = Find-SilkiSCSIRegistryInstance

    if (-not $regPath) {
        Write-Error "SilkiSCSI registry instance not found."
        return
    }

    $regPath = $regPath + "\PersistentTargets"

    $targets = $targets = Get-ChildItem -Path $regPath

    $targetArray = @()

    foreach ($t in $targets) {
        # $loginTarget = $t.PSPath + "\LoginTarget"
        # $bytes = (Get-ItemProperty -Path $loginTarget -Name LocalIPAddress).LocalIPAddress
        # $hexString = ($bytes | ForEach-Object { $_.ToString("X2") }) -join ' '

        $o = New-Object psobject 
        $o | Add-Member -MemberType NoteProperty -Name "Name" -Value $t.PSChildName
        $o | Add-Member -MemberType NoteProperty -Name "PSPath" -Value $t.name
        $targetArray += $o
    }

    if ($nodeAddress) {
        $targetArray = $targetArray | Where-Object { $_.name -like "$nodeAddress*" }
    } 

    return $targetArray

}