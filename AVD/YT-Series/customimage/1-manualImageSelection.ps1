#Make sure you have the Azure modules required

$modules = @("Az.Accounts","Az.Resources","Az.Compute")
    
foreach ($module in $modules) {
    if (!(Get-Module -Name $module -ListAvailable)) {
        Install-Module -Name $module -Force -Verbose
    }
}

#login to Azure
Login-AzAccount -Environment AzureCloud  -UseDeviceAuthentication
   
#hit the right subscription
Get-AzSubscription | Out-GridView -Title "Select the right subscription" -OutputMode Single | Select-AzSubscription

#select a location near you
$location = Get-AzLocation | Out-GridView -Title "Select your location (e.g. westeurope)" -OutputMode Single

#region select an Azure AVD Image (e.g. Windows 11) and create an Azure disk of it for later download (to onprem)
    #get the AVDs group published images by selecting 'microsoftwindowsdesktop'
    $imPub = Get-AzVMImagePublisher -Location $($location.Location) | Out-GridView -Title "Select image publisher (e.g. 'microsoftwindowsdesktop')" -OutputMode Single

    #select the AVD Desktop OS of interest e.g. 'windows-11'
    $PublisherOffer = Get-AzVMImageOffer -Location $($location.Location) -PublisherName $($imPub.PublisherName) |  Out-GridView -Title "Select your offer (e.g. windows-11)" -OutputMode Single

    # select the AVD version e.g. 'win11-21h2-avd'
    $VMImageSKU = (Get-AzVMImageSku -Location $($location.Location) -PublisherName $($imPub.PublisherName) -Offer $PublisherOffer.Offer).Skus | Out-GridView -Title "Select your imagesku (e.g. win11-22h2-avd)" -OutputMode Single

    #select latest version
    $VMImage = Get-AzVMImage -Location $($location.Location) -PublisherName $PublisherOffer.PublisherName -Offer $PublisherOffer.Offer -Skus $VMImageSKU | Out-GridView -Title "Select your version (highest build number)" -OutputMode Single

    #Create a VHDX (Gen2) from this image
    $imageOSDiskRef = @{Id = $vmImage.Id}
    $diskRG = Get-AzResourceGroup | Out-GridView -Title "Select The Target Resource Group" -OutputMode Single
    $diskName = "disk-" + $vmImage.Skus
    $newdisk = New-AzDisk -ResourceGroupName $diskRG.ResourceGroupName -DiskName "$diskName" -Disk $(New-AzDiskConfig -ImageReference $imageOSDiskRef -Location $location.Location -CreateOption FromImage -HyperVGeneration V2 -OsType Windows )

    Write-Host "You should now have a new disk named $($newdisk.name) in your resourcegroup" -ForegroundColor Green  
#endregion