resource environment 'Microsoft.App/managedEnvironments@2023-02-01' = {
  name: 'privateaca1'
  location: 'westeurope'
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: ''
        sharedKey: ''
      }
    }
    workloadProfiles: [
      {
        name: 'consumption'
        workloadProfileType: 'Consumption'
      }
      {
        name: 'd4-compute'
        workloadProfileType: 'D4'
        MinimumCount: 1
        MaximumCount: 3
      }
    ]
    vnetConfiguration: {
      infrastructureSubnetId: '/subnets/aks-5-subnet'
      internal: true
    }
    zoneRedundant: false
  }
}
