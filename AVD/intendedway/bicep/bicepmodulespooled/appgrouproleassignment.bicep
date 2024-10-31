param principalID string
param appGroupName string

var roledefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '1d18fff3-a72a-46b5-b4a9-0b38a3cd7e63')

resource targetscope 'Microsoft.DesktopVirtualization/applicationGroups@2023-09-05' existing = {
  name: appGroupName
}

resource role 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('avdadminrole-${targetscope.name}')
  scope: targetscope  
  properties: {
    roleDefinitionId: roledefinitionId
    principalId: principalID
  }
}
