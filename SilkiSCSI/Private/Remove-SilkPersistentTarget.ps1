function Remove-SilkPersistentTarget {

    param(
        [parameter(ValueFromPipeline=$true,Mandatory=$true)]
        [object]$target
    )

    begin {}

    process{
        [string] $path = $target.PSPath.replace("HKEY_LOCAL_MACHINE","HKLM:") 
        Write-Verbose $path
        Remove-Item -Path $path -Recurse
    }
}
