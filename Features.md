# AKS features lists

Get AKS features
```
az feature list --namespace Microsoft.ContainerService -o table
az feature list --namespace  Microsoft.PolicyInsights -o table
az feature list --namespace  Microsoft.DocumentDB -o table
```

Register a feature and reregister the provider
```
az feature register --name MobyImage --namespace Microsoft.ContainerService
az feature register --name AKSAuditLog --namespace Microsoft.ContainerService
az feature register --name EnableSingleIPPerCCP --namespace Microsoft.ContainerService
az feature register --name APIServerSecurityPreview --namespace Microsoft.ContainerService
az feature register --name PodSecurityPolicyPreview --namespace Microsoft.ContainerService
az feature register --name EnableNetworkPolicy --namespace Microsoft.ContainerService
az feature register --name MultiAgentpoolPreview --namespace Microsoft.ContainerService
az feature register --name AKS-RegionEarlyAccess --namespace Microsoft.ContainerService
az feature register --name V20180331API --namespace Microsoft.ContainerService
az feature register --name AksBypassServiceGate --namespace Microsoft.ContainerService
az feature register --name AvailabilityZonePreview --namespace Microsoft.ContainerService
az feature register --name WindowsPreview --namespace Microsoft.ContainerService
az feature register --name AKSLockingDownEgressPreview --namespace Microsoft.ContainerService
az feature register --name AKS-AzurePolicyAutoApprove --namespace Microsoft.ContainerService
az feature register --namespace Microsoft.PolicyInsights --name AKS-DataplaneAutoApprove
az feature register --namespace Microsoft.ContainerService/AROGA --name AKS-DataplaneAutoApprove
az feature register --namespace "Microsoft.ContainerService" --name "AKSAzureStandardLoadBalancer"
az feature register --namespace "Microsoft.ContainerService" --name "MSIPreview"
az feature register --namespace "Microsoft.ContainerService" --name "NodePublicIPPreview"
az feature register --namespace "Microsoft.ContainerService" --name "LowPriorityPoolPreview"

NodePublicIPPreview

az feature register --name OSABypassMarketplace --namespace Microsoft.ContainerService
az feature register --name AROGA --namespace Microsoft.ContainerService


```

Check if the feature is active
```
az feature list -o table --query "[?contains(name, 'Microsoft.Container‐Service/AKS-AzurePolicyAutoApprove')].{Name:name,State:properties.state}"
```

Re-register the provider
```
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.PolicyInsights
az provider unregister --namespace Microsoft.ContainerService
```

Install the preview cli
```
az extension add -n aks-preview
```

Unregister a feature
https://github.com/yangl900/armclient-go

```
curl -sL https://github.com/yangl900/armclient-go/releases/download/v0.2.3/armclient-go_linux_64-bit.tar.gz | tar xz

./armclient post /subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Features/providers/Microsoft.ContainerService/features/EnableSingleIPPerCCP/unregister?api-version=2015-12-01

./armclient post /subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Features/providers/Microsoft.ContainerService/features/APIServerSecurityPreview/unregister?api-version=2015-12-01

./armclient post /subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Features/providers/Microsoft.ContainerService/features/MultiAgentpoolPreview/unregister?api-version=2015-12-01

./armclient post /subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Features/providers/Microsoft.ContainerService/features/AKS-RegionEarlyAccess/unregister?api-version=2015-12-01
```