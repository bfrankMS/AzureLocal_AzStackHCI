@description('The name of the hostpool')
param hostpoolName string

@description('Location for all resources to be created in.')
param location string = resourceGroup().location

@description('The tags to be assigned to the resources')
param tagValues object = {
  creator: 'userxyz'
  env: 'avdPoc'
}

param tokenExpirationTime string = dateTimeAdd(utcNow('yyyy-MM-dd T00:00:00'),'P1D','o')

resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2023-09-05' = {
  name: hostpoolName
  location: location
  tags: tagValues
  properties:{
    hostPoolType: 'Pooled'
    loadBalancerType: 'BreadthFirst'
    description: 'first personal avd aadonly host pool'
    friendlyName: 'friendly name'
    preferredAppGroupType: 'Desktop'
    customRdpProperty: 'targetisaadjoined:i:1;drivestoredirect:s:*;audiomode:i:0;videoplaybackmode:i:1;redirectclipboard:i:1;redirectprinters:i:1;devicestoredirect:s:*;redirectcomports:i:1;redirectsmartcards:i:1;usbdevicestoredirect:s:*;enablecredsspsupport:i:1;redirectwebauthn:i:1;use multimon:i:1;autoreconnection enabled:i:1;bandwidthautodetect:i:1;networkautodetect:i:1;audiocapturemode:i:1;encode redirected video capture:i:1;redirected video capture encoding quality:i:2;camerastoredirect:s:*;enablerdsaadauth:i:1'
    registrationInfo: {
        expirationTime: tokenExpirationTime
        registrationTokenOperation: 'Update'
    }
  }
}

output registrationInfoToken string = reference(hostPool.id).registrationInfo.token

