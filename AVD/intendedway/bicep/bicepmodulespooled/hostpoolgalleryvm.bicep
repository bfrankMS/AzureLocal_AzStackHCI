@description('The name of the hostpool')
param hostpoolName string

@description('The token for adding VMs to the hostpool')
param hostpoolToken string = ''

@description('(Required when vmImageType = Gallery) Gallery image Offer.')
param vmGalleryImageOffer string = 'office-365'
//param vmGalleryImageOffer string = 'windows-10'

@description('(Required when vmImageType = Gallery) Gallery image Publisher.')
param vmGalleryImagePublisher string = 'MicrosoftWindowsDesktop'

@description('(Required when vmImageType = Gallery) Gallery image SKU.')
param vmGalleryImageSKU string = 'win11-23h2-avd-m365'
//param vmGalleryImageSKU string = 'win10-22h2-avd-g2'

@description('This prefix will be used in combination with the VM number to create the VM name. This value includes the dash, so if using \'rdsh\' as the prefix, VMs would be named \'rdsh-0\', \'rdsh-1\', etc. You should use a unique prefix to reduce name collisions in Active Directory.')
param vmPrefix string = take(toLower('$hostpoolName-vm'), 10)

@description('This is the suffix to the vm names. VM will be named \'[vmPrefix]-[vmInstanceSuffixes]\'')
param vmInstanceSuffixes array = [
  '0'
  '1'
]

@allowed([
  'Premium_LRS'
  'StandardSSD_LRS'
  'Standard_LRS'
  'UltraSSD_LRS'
])
@description('The VM disk type for the VM: HDD or SSD.')
param vmDiskType string = 'Standard_LRS'

@description('The size of the session host VMs.')
param vmSize string = 'Standard_D2s_v4' // 'Standard_A2'

@description('intune mdm id')
param intune bool = false
/*
Standard_B2ms   
Standard_B2s    
Standard_DS2_v2 
Standard_F2s    
Standard_D2s_v3 
Standard_D2s_v4 
Standard_F2s_v2 
Standard_D2as_v4
*/

@description('Enables Accelerated Networking feature, notice that VM size must support it, this is supported in most of general purpose and compute-optimized instances with 2 or more vCPUs, on instances that supports hyperthreading it is required minimum of 4 vCPUs.')
param enableAcceleratedNetworking bool = true

@description('The username for the admin.')
param administratorAccountUsername string

@description('The password that corresponds to the existing domain username.')
@secure()
param administratorAccountPassword string

@description('The unique id of the subnet for the nics.')
param subnet_id string

@description('Location for all resources to be created in.')
param location string = resourceGroup().location

//@description('The rules to be given to the new network security group')
//param networkSecurityGroupRules array = []

//@description('OUPath for the domain join')
//param ouPath string = ''

//@description('Domain to join')
//param domain string = ''

@description('The tags to be assigned to the resources')
param tagValues object = {
  creator: 'bfrank'
  env: 'avdPoc'
}

var WvdAgentArtifactsLocation = 'https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_1.0.02454.213.zip' //'https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_7-12-2021.zip'
var artifactsLocationSASToken = ''
//var existingDomainUsername = first(split(administratorAccountUsername, '@'))
//var domainName = ((domain == '') ? last(split(administratorAccountUsername, '@')) : domain)
var storageAccountType = vmDiskType
//var newNsgNameVariable = '${vmPrefix}-nsg'

/*
resource newNsgName 'Microsoft.Network/networkSecurityGroups@2023-06-01' = {
  name: newNsgNameVariable
  location: location
  tags: tagValues
  properties: {
    securityRules: networkSecurityGroupRules
  }
}
*/

resource vmPrefix_vmInstanceSuffixes_nic 'Microsoft.Network/networkInterfaces@2023-06-01' = [for item in vmInstanceSuffixes: {
  name: '${vmPrefix}${item}-nic'
  location: location
  tags: tagValues
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnet_id
          }
        }
      }
    ]
    enableAcceleratedNetworking: enableAcceleratedNetworking
    //networkSecurityGroup: json('{"id": "${newNsgName.id}"}')
  }
  /*
  dependsOn: [
    newNsgName
    ]
  */
}]

resource vmPrefix_vmInstanceSuffixes 'Microsoft.Compute/virtualMachines@2023-09-01' = [for item in vmInstanceSuffixes: {
  name: '${vmPrefix}${item}'
  location: location
  tags: tagValues
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: '${vmPrefix}${item}'
      adminUsername: administratorAccountUsername
      adminPassword: administratorAccountPassword
    }
    storageProfile: {
      imageReference: {
        publisher: vmGalleryImagePublisher
        offer: vmGalleryImageOffer
        sku: vmGalleryImageSKU
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        name: '${vmPrefix}${item}-osdisk'
        managedDisk: {
          storageAccountType: storageAccountType
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: resourceId('Microsoft.Network/networkInterfaces', '${vmPrefix}${item}-nic')
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: false
      }
    }
    licenseType: 'Windows_Client'
  }
  dependsOn: [
    vmPrefix_vmInstanceSuffixes_nic
  ]
}]

/*
resource vmPrefix_vmInstanceSuffixes_joindomain 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = [for item in vmInstanceSuffixes: {
  name: '${vmPrefix}${item}/joindomain'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'JsonADDomainExtension'
    typeHandlerVersion: '1.3'
    autoUpgradeMinorVersion: true
    settings: {
      name: domainName
      ouPath: ouPath
      user: '${administratorAccountUsername}@${domainName}'
      restart: 'true'
      options: '3'
    }
    protectedSettings: {
      password: administratorAccountPassword
    }
  }
  dependsOn: [
    vmPrefix_vmInstanceSuffixes
  ]
}]
*/

resource vmPrefix_vmInstanceSuffixes_aadjoin 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = [for item in vmInstanceSuffixes: {
  name: '${vmPrefix}${item}/AADLoginForWindows'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.ActiveDirectory'
    type: 'AADLoginForWindows'
    typeHandlerVersion: '2.0'
    autoUpgradeMinorVersion: true
    settings: intune ?{
      mdmId: '0000000a-0000-0000-c000-000000000000'
    }: null
  }
  dependsOn: [
    vmPrefix_vmInstanceSuffixes_dscextension
  ]
}]

resource vmPrefix_vmInstanceSuffixes_dscextension 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = [for item in vmInstanceSuffixes: {
  name: '${vmPrefix}${item}/Microsoft.PowerShell.DSC'
  location: location
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.73'
    autoUpgradeMinorVersion: true
    settings: {
      modulesUrl: '${WvdAgentArtifactsLocation}${artifactsLocationSASToken}'
      configurationFunction: 'Configuration.ps1\\AddSessionHost'
      properties: {
        hostPoolName: hostpoolName
        registrationInfoToken: hostpoolToken
        mdmId: intune ? '0000000a-0000-0000-c000-000000000000' : ''
        aadJoin: true
        aadJoinPreview:false
        UseAgentDownloadEndpoint: true
        sessionHostConfigurationLastUpdateTime: false
      }
    }
  }
  dependsOn: [
vmPrefix_vmInstanceSuffixes
]
}]

output vmNames array = [for item in vmInstanceSuffixes: '${vmPrefix}${item}']


