param hostPoolName string = ''
param hostPoolRG string = resourceGroup().name
param location string = resourceGroup().location
param tagValues object = {}

var applicationgroupName = '${hostPoolName}-DAG'
var hostpoolsID = '/subscriptions/${subscription().subscriptionId}/resourceGroups/${hostPoolRG}/providers/Microsoft.DesktopVirtualization/hostpools/${hostPoolName}'
var friendlyName = '${hostPoolName} Desktop Application Group'

resource applicationgroup 'Microsoft.DesktopVirtualization/applicationgroups@2023-09-05' = {
  name: applicationgroupName
  location: location
  kind: 'Desktop'
  tags: tagValues
  properties: {
    hostPoolArmPath: hostpoolsID
    description: 'Desktop Application Group created through ARM template'
    friendlyName: friendlyName
    applicationGroupType: 'Desktop'
  }
}
output applicationGroupID string = applicationgroup.id
output applicationGroupName string = applicationgroup.name
