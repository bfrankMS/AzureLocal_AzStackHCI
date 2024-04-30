
$SubscriptionId = 'a2ba...???...57e6f'           # your Azure subscription ID
$tenantId = '47f4...???...65aab0'               # your Azure Entra ID tenant ID
$resourceGroup = "...???..."               # please change me!
$locationHostPool = "westeurope"
$administratorAccountPassword = "...???..."     # please change me!
$administratorAccountUsername = "...???..."  # please change me!
$hostpoolName = "...???..."                      # please change me!
$imageName = "win11-avd"                # please change me!
$imageRG = "...???..."                # please change me!

az login --use-device-code --tenant $tenantId
az account set --subscription $SubscriptionId  
az group create --name $resourceGroup --location $locationHostPool

$principalID = $(az ad group show --group 'AVD Users...???...') | ConvertFrom-Json   #Change to a that exists in your Azure AD

$imageID = $(az stack-hci-vm image show --name $imageName --resource-group $imageRG) | ConvertFrom-Json   #Change to a that exists in your Azure AD


if ($null -eq $principalID) {
  Write-Host "You need to create a group called 'AVD Users' in the Azure AD and assign the users to it. Then run this script again." -ForegroundColor red
  break
}


az deployment group create  `
  --name $("avd_" + ([datetime]::Now).ToString('dd-MM-yy_HH_mm')) `
  --template-file "$((Get-Location).Path)\AVDOnPremise.json" `
  --resource-group $resourceGroup `
  --parameters location=$locationHostPool `
  administratorAccountPassword=$administratorAccountPassword  `
  administratorAccountUsername=$administratorAccountUsername `
  domain='my...???...org' `
  oUPath='OU=AVD,DC=my...???...,DC=org' `
  logicalNetworkId='/subscriptions/a2...???...e6f/resourceGroups/rg...???.../providers/microsoft.azurestackhci/logicalnetworks/lnet...???...atic' `
  configurationZipUri='https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_1.0.02608.268.zip' `
  customLocationId='/subscriptions/a2ba2440-3367-4053-86aa-07bcecc57e6f/resourceGroups/rg...???.../providers/Microsoft.ExtendedLocation/customLocations/...???...location' `
  domainAdministratorPassword='...???...' `
  domainAdministratorUsername='djoiner@my...???...org' `
  fileUri='https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/HCIScripts_1.0.02608.268/HciCustomScript.ps1' `
  imageId=$($imageID.id) `
  memoryMB=8192 `
  virtualProcessorCount=4 `
  hostpoolName=$hostpoolName `
  hostPoolRG=$resourceGroup `
  principalID=$($principalID.id) `
  workspaceName="$hostpoolName-WS" `
  workspaceFriendlyName="Cloud Workspace hosting $hostpoolName" `
  currentDate=$(([datetime]::Now).ToString('dd-MM_HH_mm')) tagValues=$('{\"CreatedBy\": \"someone\",\"deploymentDate\": \"'+ $(([datetime]::Now).ToString('dd-MM-yyyy_HH_mm')) + '\",\"Service\": \"AVD\",\"Environment\": \"HCI\"}')

