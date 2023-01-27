@description('Datacenter location.')
param location string = resourceGroup().location

@description('Specifies a project name that is used to generate the Event Hub name and the Namespace name.')
param projectName string

@description('Resource Id of the managed identity for the AKS Controller Identity.')
param controllerIdentity string

@description('Resource Id of the subnet that will be used for the AKS cluster.')
param nodePoolSubnetId string

@description('Object id of the subnet that will be used for the AKS cluster.')
param aksAdminGroupId string

module logging 'logging.bicep' = {
  name: 'logging'
  params: {
    location: location
    logAnalyticsWorkspaceName: 'log-${projectName}'
  }
}

module aks 'aks.bicep' = {
  name: 'aks'
  params: {
    location: location
    clusterName: projectName
    controllerIdentity: controllerIdentity
    nodePoolSubnetId: nodePoolSubnetId
    aksAdminGroupId: aksAdminGroupId
    workspaceResourceId: logging.outputs.logAnalyticsWorkspaceId
  }
}
