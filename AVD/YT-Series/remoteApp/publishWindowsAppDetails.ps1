#######################
# run this as Administrator on one AVD session host (ie. machine where the app is installed)
# copy the output and use it when editing the Remote Application Group in the AVD portal
#######################

$selectedPackage = Get-AppxPackage -AllUsers | Sort-Object Name | Select-Object Name, PackageFamilyName,InstallLocation | Out-GridView -OutputMode Single
$packageFamilyName = $selectedPackage.PackageFamilyName
$packagemanifest = (Get-AppxPackage -AllUsers | ? PackageFamilyName -eq $packageFamilyName | Get-AppxPackageManifest)

$filePath = "shell:appsFolder\$($packageFamilyName)!$($packagemanifest.Package.Applications.Application.Id)"

# find suitable logo for selected package
$initialDirectory = "$($selectedPackage.InstallLocation)\$(split-path $(($packagemanifest | Select-Object -First 1).package.properties.logo) -Parent)"

[void] [System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')
$OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
if ($initialDirectory) { $OpenFileDialog.initialDirectory = $initialDirectory }
$OpenFileDialog.filter = "png files (*.png)|*.png|jpg files (*.jpg)|*.png|All files (*.*)|*.*"
$OpenFileDialog.ShowDialog()
$iconPath = $OpenFileDialog.FileName

$output = @"
=============
Filepath: $filePath
Iconpath: $iconPath
=============
"@

Write-Host $output -ForegroundColor Magenta  