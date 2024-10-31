$SubscriptionId = 'a2ba2.....cc57e6f'           # your Azure subscription ID
$tenantId = '47f489.f65aab0'               # your Azure Entra ID tenant ID
$resourceGroup = "rg-MX.....H2-res"               # please change me!
$locationHostPool = "westeurope"
$administratorAccountPassword = "L.....1!"     # please change me!
$administratorAccountUsername = "bfrank"  # please change me!
$hostpoolName = "HCIMX....."                      # please change me!

az login --use-device-code --tenant $tenantId
az account set --subscription $SubscriptionId  
az group create --name $resourceGroup --location $locationHostPool


az deployment group create  `
  --name $("avd_" + ([datetime]::Now).ToString('dd-MM-yy_HH_mm')) `
  --template-file "$((Get-Location).Path)\AVDOnPremiseVMOnlyProxy.json" `
  --resource-group $resourceGroup `
  --parameters location=$locationHostPool `
  vmAdministratorAccountPassword=$administratorAccountPassword  `
  vmAdministratorAccountUsername=$administratorAccountUsername `
  domainAdministratorPassword='L.....1!' `
  domainAdministratorUsername='djoiner@my.....avd.org' `
  domain='my.....avd.org' `
  oUPath='OU=HCIMX.....,OU=AVD.....,DC=my.....avd,DC=org' `
  customLocationId='/subscriptions/a2ba.....7e6f/resourceGroups/rg-MX1020-23H2/providers/Microsoft.ExtendedLocation/customLocations/MX-cl' `
  logicalNetworkId='/subscriptions/a2ba.....e6f/resourceGroups/rg-MX1020-23H2/providers/microsoft.azurestackhci/logicalnetworks/lnetmyavdstaticproxy' `
  imageId="/subscriptions/a2ba.....7e6f/resourceGroups/rg-MX1020-23H2/providers/microsoft.azurestackhci/galleryimages/W11AvdM365Opt" `
  configurationZipUri='https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_1.0.02608.268.zip' `
  fileUri='https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/HCIScripts_1.0.02608.268/HciCustomScript.ps1' `
  httpProxy='http://172.......1:3128' `
  memoryMB=16384 `
  virtualProcessorCount=8 `
  hostpoolName=$hostpoolName `
  hostpoolToken='eyJhbGciOiJSUzI1Ni.....-G-OFA' `
  vmInstanceSuffixes="[""10"",""11""]" `
  tagValues=$('{\"CreatedBy\": \"bfrank\",\"deploymentDate\": \"'+ $(([datetime]::Now).ToString('dd-MM-yyyy_HH_mm')) + '\",\"Service\": \"AVD\",\"Environment\": \"PoC\"}')

