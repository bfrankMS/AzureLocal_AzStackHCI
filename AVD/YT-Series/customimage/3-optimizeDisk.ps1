# execute this on the hyper-v node

# e.g. enter-pssession %YourNodeName%

#region Convert to a dynamic vhdx!
$sourceDiskPath = "C:\ClusterStorage\COLLECT\Images\disk-win11-24h2-avd-m365.vhd"
$finalfolder = "C:\clusterstorage\COLLECT\Images"        # pls enter an existing final destination to hold the AVD image.
$diskFinalDestination = "$finalfolder\$((split-path -leaf $sourceDiskPath).Replace('vhd','vhdx'))"


Convert-VHD -Path "$sourceDiskPath" -DestinationPath "$diskFinalDestination" -VHDType Dynamic

try
{
    $beforeMount = (Get-Volume).DriveLetter -split ' '
    Mount-VHD -Path $diskFinalDestination
    $afterMount = (Get-Volume).DriveLetter -split ' '
    $driveLetter = $([string](Compare-Object $beforeMount $afterMount -PassThru )).Trim()
    Write-Host "Optimizing disk ($($driveLetter)): $diskFinalDestination" -ForegroundColor Green
    &defrag "$($driveLetter):" /o /u /v
}
finally
{
    Write-Host "dismounting ..."
    Dismount-VHD -Path $diskFinalDestination
}
  
Optimize-VHD $diskFinalDestination -Mode full
#endregion