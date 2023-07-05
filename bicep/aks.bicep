@description('Location for the Cosmos DB account.')
param location string = resourceGroup().location
param clusterName string
param vmSize string = 'Standard_B4ms'
param controllerIdentity string
param nodePoolSubnetId string
param workspaceResourceId string
param aksAdminGroupId string

// https://learn.microsoft.com/en-us/azure/templates/microsoft.containerservice/managedclusters?pivots=deployment-language-bicep
resource aks 'Microsoft.ContainerService/managedClusters@2023-05-02-preview' = {
  name: clusterName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${controllerIdentity}': {
      }
    }       
  }
  sku: {
    name: 'Basic'
    tier: 'Paid'
  }
  properties: {
    dnsPrefix: clusterName
    enableRBAC: true
    aadProfile: {
      adminGroupObjectIDs: [
        '${aksAdminGroupId}'
      ]
      managed: true
    }
    kubernetesVersion: '1.26'
    nodeResourceGroup: '${clusterName}-infra'
    apiServerAccessProfile: {
      enablePrivateCluster: true
      enablePrivateClusterPublicFQDN: true
      disableRunCommand: true
    }
    servicePrincipalProfile: {
      clientId: 'msi'
    }
    agentPoolProfiles: [
      {
        availabilityZones: [
          '1'
          '2'
          '3'
        ]
        name: 'default'
        //osDiskType: 'Ephemeral'
        enableAutoScaling: true
        count: 4
        minCount: 3
        maxCount: 10
        vmSize: vmSize
        vnetSubnetID: nodePoolSubnetId
        mode: 'System'
      }
    ]
    networkProfile: {
      networkPlugin: 'kubenet'
      networkPolicy: 'calico'
      loadBalancerSku: 'standard'
      outboundType: 'loadBalancer'
      dockerBridgeCidr: '172.17.0.1/16'
      dnsServiceIP: '10.1.0.10'
      serviceCidr: '10.1.0.0/16'
    }
    azureMonitorProfile: {
      enabled: true
    }
    ingressProfile: {
      webAppRouting: {
        enabled: true
      }
    }
    guardrailsProfile: {
      enabled: true
      systemExcludedNamespaces: [ 'kube-system']
      level: 'Enforce'
      excludedNamespaces: 'istio-system'
    }
    serviceMeshProfile : {
      enabled: true
    }
    addonProfiles: {
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: workspaceResourceId
        }
      }
    }
    publicNetworkAccess: 'Disabled'
    disableLocalAccounts: true
    
  }
}
