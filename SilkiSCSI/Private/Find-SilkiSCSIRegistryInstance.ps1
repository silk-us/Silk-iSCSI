function Find-SilkiSCSIRegistryInstance {
    $property = "DriverDesc"
    $regLocal = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e97b-e325-11ce-bfc1-08002be10318}'
    $paths = Get-ChildItem -Path $regLocal -Recurse -ErrorAction SilentlyContinue

    foreach ($path in $paths) {
        $psPath = $path.name.replace('HKEY_LOCAL_MACHINE','HKLM:')
        $propertyValue = Get-ItemProperty -Path $psPath -Name $property -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $property
        if ($propertyValue -eq "Microsoft iSCSI Initiator") {
            $targetPath = $psPath
        }
    }

    if ($targetPath) {
        return $targetPath
    } else {
        $message = 'Microsoft iSCSI Initiator not found in the registry.'
        Write-Error $message
    }
}