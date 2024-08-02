
$SubscriptionId = 'a2b.....e6f'           # your Azure subscription ID
$tenantId = '47f489.....5aab0'               # your Azure Entra ID tenant ID
$resourceGroup = "rg-M.....2-res"               # please change me!
$location = "westeurope"
$administratorAccountPassword = 'L.....!'     # please change me!
$administratorAccountUsername = "b.....k"  # please change me!
$vmPrefix = "HCIVM" # please change me!

az login --use-device-code --tenant $tenantId
az account set --subscription $SubscriptionId  
az group create --name $resourceGroup --location $resourceGroup

# This will deploy an array of Azure Arc managed VMs
# including a AzMonitor agent installed, a run commmand to install SSH access and a custom script extension to execute a script from a blob storage.
# https://learn.microsoft.com/en-us/azure-stack/hci/manage/azure-arc-vm-management-overview
az deployment group create  `
  --name $("vm_" + ([datetime]::Now).ToString('dd-MM-yy_HH_mm')) `
  --template-file "$((Get-Location).Path)\VMCopyOnPremiseWithExtensions.json" `
  --resource-group $resourceGroup `
  --parameters location=$location `
  vmPrefix=$vmPrefix `
  vmAdministratorPassword=$administratorAccountPassword  `
  vmAdministratorUsername=$administratorAccountUsername `
  logicalNetworkId='/subscriptions/a2b.....e6f/resourceGroups/rg-M.....2-res/providers/microsoft.azurestackhci/logicalnetworks/lnet.....static' `
  customLocationId='/subscriptions/a2b.....e6f/resourceGroups/rg-M.....2-res/providers/Microsoft.ExtendedLocation/customLocations/.....cl' `
  imageId="/subscriptions/a2b.....e6f/resourceGroups/rg-M.....2-res/providers/microsoft.azurestackhci/galleryimages/W11.....M365Opt"  `
  memoryMB=8192 `
  virtualProcessorCount=6 `
  vmInstanceSuffixes="[""1"",""2""]" `
  param1='Hello' `
  param2='World' `
  cseURI='https://......blob.core.windows.net/somecon....tainer/someCSE.ps1' `
  tagValues=$('{\"CreatedBy\": \"bfrank\",\"deploymentDate\": \"'+ $(([datetime]::Now).ToString('dd-MM-yyyy_HH_mm')) + '\",\"Service\": \"ARB\",\"Environment\": \"PoC\"}') `
  sasToken='"sp=r&st=2024-0....."'  # please replace with a valid SAS read acces token ! and yes keep the '"...."' format when launching az deployment group create from PowerShell
  

