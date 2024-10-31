param principalID string
param vms array = []

var VirtualMachineUserLogin_role = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'fb879df8-f326-4884-b1cf-06f3ad86be52')

resource targetscope 'Microsoft.Compute/virtualMachines@2023-09-01' existing = [for item in vms: {
  name: item
}]


resource role1 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for i in range(0, length(vms)): {
  name: guid('avduserrole-${targetscope[i].name}')
  scope: targetscope[i]
  properties: {
    roleDefinitionId: VirtualMachineUserLogin_role
    principalId: principalID
  }
}]

