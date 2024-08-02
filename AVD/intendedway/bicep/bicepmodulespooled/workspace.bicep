param workspaceName string = ''
param tagValues object
param workspaceFriendlyName string = 'Cloud Workspace'

@description('description')
param applicationGroups array = [
 ] 
@description('name of your avd workspace')
param location string = resourceGroup().location

resource workspacesName_resource 'Microsoft.DesktopVirtualization/workspaces@2023-09-05' = {
  name: workspaceName
  location: location
  tags: tagValues
  properties: {
    friendlyName: workspaceFriendlyName
    applicationGroupReferences: applicationGroups
  }
}
