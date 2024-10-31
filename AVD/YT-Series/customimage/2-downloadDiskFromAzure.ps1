#region Create a temp. download link and download the disk as virtual disk (.vhd)
$AccessSAS =  $newdisk | Grant-AzDiskAccess -DurationInSecond ([System.TimeSpan]::Parse("05:00:00").TotalSeconds) -Access 'Read'
Write-Host "Generating a temporary download access token for $($newdisk.Name)" -ForegroundColor Green 
$DiskURI = $AccessSAS.AccessSAS

$folder = "\\....\c$\ClusterStorage\...\Images"   #enter one of the nodes here - the path must be accessible by the user - beware that there is enough space (127GB) for the disk to be downloaded.

$diskDestination = "$folder\$($newdisk.Name).vhd"
Write-Host "Your disk will be placed into: $diskDestination" -ForegroundColor Green
#"Start-BitsTransfer ""$DiskURI"" ""$diskDestination"" -Priority High -RetryInterval 60 -Verbose -TransferType Download"

#or use azcopy as it is much faster!!!
invoke-webrequest -uri "https://aka.ms/downloadazcopy-v10-windows" -OutFile "$env:TEMP\azcopy.zip" -verbose
Expand-Archive "$env:TEMP\azcopy.zip" "$env:TEMP" -force -verbose
copy-item "$env:TEMP\azcopy_windows_amd64_*\\azcopy.exe\\" -Destination "$env:TEMP" -verbose
cd "$env:TEMP\"
&.\azcopy.exe copy $DiskURI $diskDestination --log-level INFO
Remove-Item "azcopy*" -Recurse  #cleanup temp
#endregion