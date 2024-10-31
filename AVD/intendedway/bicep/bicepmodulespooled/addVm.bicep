@description('This prefix will be used in combination with the VM number to create the VM name. This value includes the dash, so if using “rdsh” as the prefix, VMs would be named “rdsh-0”, “rdsh-1”, etc. You should use a unique prefix to reduce name collisions in Active Directory.')
param rdshPrefix string = take(toLower(resourceGroup().name), 10)

@description('Virtual Processor Count')
param virtualProcessorCount int

@description('The total amount of memory in megabytes')
param memoryMB int

@description('This parameter is optional and only used if dynamicMemory = true. When using dynamic memory this setting is the maximum MB given to the VM.')
param maximumMemoryMB int = 0

@description('This parameter is optional and only used if dynamicMemory = true. When using dynamic memory this setting is the minimum MB given to the VM.')
param minimumMemoryMB int = 0

@description('True if you want to use a dynamic memory config.')
param dynamicMemoryConfig bool = false

@description('This parameter is optional and only used if dynamicMemory = true. When using dynamic memory this setting is the buffer of extra memory given to the VM.')
param targetMemoryBuffer int = 0

@description('VM name prefix initial number.')
param vmInitialNumber int = 0

@description('The tags to be assigned to the network interfaces')
param networkInterfaceTags object = {}

@description('The tags to be assigned to the virtual machines')
param virtualMachineTags object = {}

@description('The location where the resources will be deployed.')
param location string

@description('A deployment target created and customized by your organization for creating virtual machines. The custom location is associated to an Azure Stack HCI cluster.')
param customLocationId string

@description('The username for the domain admin.')
param domainAdministratorUsername string

@description('The password that corresponds to the existing domain username.')
@secure()
param domainAdministratorPassword string

@description('A username to be used as the virtual machine administrator account. The vmAdministratorAccountUsername and  vmAdministratorAccountPassword parameters must both be provided. Otherwise, domain administrator credentials provided by domainAdministratorUsername and domainAdministratorPassword will be used.')
param vmAdministratorAccountUsername string = ''

@description('The password associated with the virtual machine administrator account. The vmAdministratorAccountUsername and  vmAdministratorAccountPassword parameters must both be provided. Otherwise, domain administrator credentials provided by domainAdministratorUsername and domainAdministratorPassword will be used.')
@secure()
param vmAdministratorAccountPassword string = ''

@description('Full ARM resource ID of the AzureStackHCI virtual network used for the VMs.')
param logicalNetworkId string

@description('Full ARM resource ID of the AzureStackHCI virtual machine image used for the VMs.')
param imageId string

@description('The name of the hostpool')
param hostpoolName string

@description('The token for adding VMs to the hostpool')
param hostpoolToken string

@description('Session host configuration version of the host pool.')
param SessionHostConfigurationVersion string = ''

@description('Number of session hosts that will be created and added to the hostpool.')
param rdshNumberOfInstances int

@description('OU Path for the domain join')
param oUPath string = ''

@description('Domain to join')
param domain string = ''

@description('Uri to download file that is executed in the custom script extension')
param fileUri string

@description('Uri to download file that is executed in the custom script extension')
param fileName string = 'HciCustomScript.ps1'

@description('The base URI where the Configuration.zip script is located to install the AVD agent on the VM')
param configurationZipUri string

@description('IMPORTANT: You can use this parameter for the test purpose only as AAD Join is public preview. True if AAD Join, false if AD join')
param aadJoin bool = false

@description('IMPORTANT: Please don\'t use this parameter as intune enrollment is not supported yet. True if intune enrollment is selected.  False otherwise')
param intune bool = false

@description('System data is used for internal purposes, such as support preview features.')
param systemData object = {}

var domain_var = ((domain == '') ? last(split(domainAdministratorUsername, '@')) : domain)
var hostPoolNameArgument = '-HostPoolName ${hostpoolName}'
var registrationTokenArgument = ' -RegistrationInfoToken  ${hostpoolToken}'
var sessionHostConfigurationLastUpdateTimeArgument = ' -SessionHostConfigurationLastUpdateTime ${SessionHostConfigurationVersion}'
var artifactUriArgument = ' -ArtifactUri ${configurationZipUri}'
var customScriptParentFolder = split(fileUri, '/')[4]
var customScriptFilePath = '${customScriptParentFolder}/${fileName}'
var arguments = concat(hostPoolNameArgument, registrationTokenArgument, artifactUriArgument)
var isVMAdminAccountCredentialsProvided = ((vmAdministratorAccountUsername != '') && (vmAdministratorAccountPassword != ''))
var vmAdministratorUsername = (isVMAdminAccountCredentialsProvided ? vmAdministratorAccountUsername : first(split(domainAdministratorUsername, '@')))
var vmAdministratorPassword = (isVMAdminAccountCredentialsProvided ? vmAdministratorAccountPassword : domainAdministratorPassword)

resource rdshPrefix_vmInitialNumber_nic 'Microsoft.AzureStackHCI/networkinterfaces@2023-09-01-preview' = [for i in range(0, rdshNumberOfInstances): {
  name: '${rdshPrefix}${(i + vmInitialNumber)}-nic'
  location: location
  extendedLocation: {
    type: 'CustomLocation'
    name: customLocationId
  }
  tags: networkInterfaceTags
  properties: {
    ipConfigurations: [
      {
        name: '${rdshPrefix}${(i + vmInitialNumber)}-nic'
        properties: {
          subnet: {
            id: logicalNetworkId
          }
        }
      }
    ]
  }
}]

resource rdshPrefix_vmInitialNumber 'Microsoft.HybridCompute/machines@2023-03-15-preview' = [for i in range(0, rdshNumberOfInstances): {
  name: concat(rdshPrefix, (i + vmInitialNumber))
  location: location
  kind: 'HCI'
  identity: {
    type: 'SystemAssigned'
  }
}]

resource default 'microsoft.azurestackhci/virtualmachineinstances@2023-09-01-preview' = [for i in range(0, rdshNumberOfInstances): {
  scope: 'Microsoft.HybridCompute/machines/${rdshPrefix}${(i + vmInitialNumber)}'
  name: 'default'
  extendedLocation: {
    type: 'CustomLocation'
    name: customLocationId
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: 'Custom'
      processors: virtualProcessorCount
      memoryMB: memoryMB
      dynamicMemoryConfig: (dynamicMemoryConfig ? {
        maximumMemoryMB: maximumMemoryMB
        minimumMemoryMB: minimumMemoryMB
        targetMemoryBuffer: targetMemoryBuffer
      } : json('null'))
    }
    osProfile: {
      adminUsername: vmAdministratorUsername
      adminPassword: vmAdministratorPassword
      windowsConfiguration: {
        provisionVMAgent: true
      }
      computerName: concat(rdshPrefix, (i + vmInitialNumber))
    }
    storageProfile: {
      imageReference: {
        id: imageId
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: resourceId('Microsoft.AzureStackHCI/networkinterfaces', '${rdshPrefix}${(i + vmInitialNumber)}-nic')
        }
      ]
    }
  }
  dependsOn: [
    rdshPrefix_vmInitialNumber
    'Microsoft.AzureStackHCI/networkInterfaces/${rdshPrefix}${(i + vmInitialNumber)}-nic'
  ]
}]

resource rdshPrefix_vmInitialNumber_CustomScriptExtension 'Microsoft.HybridCompute/machines/extensions@2023-03-15-preview' = [for i in range(0, rdshNumberOfInstances): {
  name: '${rdshPrefix}${(i + vmInitialNumber)}/CustomScriptExtension'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        fileUri
      ]
    }
    protectedSettings: {
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -File ${customScriptFilePath} ${arguments}'
    }
  }
  dependsOn: [
    default
  ]
}]

resource rdshPrefix_vmInitialNumber_AADLoginForWindows 'Microsoft.HybridCompute/machines/extensions@2023-03-15-preview' = [for i in range(0, rdshNumberOfInstances): if (aadJoin && (contains(systemData, 'aadJoinPreview') ? (!systemData.aadJoinPreview) : bool('true'))) {
  name: '${rdshPrefix}${(i + vmInitialNumber)}/AADLoginForWindows'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.ActiveDirectory'
    type: 'AADLoginForWindows'
    typeHandlerVersion: '2.0'
    autoUpgradeMinorVersion: true
    settings: (intune ? {
      mdmId: '0000000a-0000-0000-c000-000000000000'
    } : {
      mdmId: ''
    })
  }
  dependsOn: [
    rdshPrefix_vmInitialNumber_CustomScriptExtension
  ]
}]

resource rdshPrefix_vmInitialNumber_joindomain 'Microsoft.HybridCompute/machines/extensions@2023-03-15-preview' = [for i in range(0, rdshNumberOfInstances): if (!aadJoin) {
  name: '${rdshPrefix}${(i + vmInitialNumber)}/joindomain'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'JsonADDomainExtension'
    typeHandlerVersion: '1.3'
    autoUpgradeMinorVersion: true
    settings: {
      name: domain_var
      oUPath: oUPath
      user: domainAdministratorUsername
      restart: 'true'
      options: '3'
    }
    protectedSettings: {
      password: domainAdministratorPassword
    }
  }
  dependsOn: [
    rdshPrefix_vmInitialNumber_CustomScriptExtension
  ]
}]

resource rdshPrefix_vmInitialNumber_azmonitor 'Microsoft.HybridCompute/machines/extensions@2023-03-15-preview' = [for i in range(0, rdshNumberOfInstances): {
  name: '${rdshPrefix}${(i + vmInitialNumber)}/azmonitor'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorWindowsAgent'
    typeHandlerVersion: '1.5'
    autoUpgradeMinorVersion: true
  }
  dependsOn: [
    rdshPrefix_vmInitialNumber_joindomain
  ]
}]