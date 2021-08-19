# AKS features lists

Get AKS features
```
az feature list --namespace Microsoft.ContainerService -o table
az feature list --namespace Microsoft.PolicyInsights -o table
az feature list --namespace Microsoft.DocumentDB -o table
az feature list --namespace Microsoft.Network -o table
az feature list --namespace Microsoft.Storage -o table
az feature list --namespace Microsoft.RedHatOpenShift -o table
az feature list --namespace Microsoft.Web -o table
az feature list --namespace Microsoft.Compute -o table
az feature list --namespace Microsoft.Kubernetes -o table
az feature list --namespace Microsoft.KubernetesConfiguration -o table
az feature list --namespace Microsoft.EventGrid -o table
az feature list --namespace Microsoft.OperationalInsights -o table

```

Register a feature and reregister the provider
```
az feature register --name CustomNodeConfigPreview --namespace Microsoft.ContainerService
az feature register --name PodSubnetPreview --namespace Microsoft.ContainerService
az feature register --name EnableACRTeleport --namespace Microsoft.ContainerService
az feature register --name AutoUpgradePreview --namespace Microsoft.ContainerService
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
az feature register --namespace "Microsoft.ContainerService" --name "OpenVPN"
az feature register --namespace "Microsoft.ContainerService" --name "SpotPoolPreview"
az feature register --namespace "Microsoft.ContainerService" --name "AKS-AzurePolicyV2"
az feature register --namespace "Microsoft.ContainerService" --name "AKS-IngressApplicationGatewayAddon"
az feature register --namespace "Microsoft.ContainerService" --name "UseCustomizedContainerRuntime"
az feature register --namespace "Microsoft.ContainerService" --name "UserAssignedIdentityPreview"
az feature register --namespace "Microsoft.ContainerService" --name "useContainerd"
az feature register --namespace "Microsoft.ContainerService" --name "EnableAzureDiskFileCSIDriver"
az feature register --namespace "Microsoft.ContainerService" --name "EnableUltraSSD"
az feature register --namespace "Microsoft.ContainerService" --name "ProximityPlacementGroupPreview"
az feature register --namespace "Microsoft.ContainerService" --name "NodeImageUpgradePreview"
az feature register --namespace "Microsoft.ContainerService" --name "MaxSurgePreview"
az feature register --namespace "Microsoft.ContainerService" --name "AKS-GitOps"
az feature register --namespace "Microsoft.ContainerService" --name "AKSNetworkModePreview"
az feature register --namespace "Microsoft.ContainerService" --name "GPUDedicatedVHDPreview"
az feature register --namespace "Microsoft.ContainerService" --name "AKSHTTPCustomFeatures"
az feature register --namespace "Microsoft.ContainerService" --name "EnableEphemeralOSDiskPreview"
az feature register --namespace "Microsoft.ContainerService" --name "StartStopPreview"
az feature register --namespace "Microsoft.ContainerService" --name "AKS-OpenServiceMesh"
az feature register --namespace "Microsoft.ContainerService" --name "EnablePodIdentityPreview"
az feature register --namespace "Microsoft.ContainerService" --name "AKS-OMSAppMonitoring"
az feature register --namespace "Microsoft.ContainerService" --name "MigrateToMSIClusterPreview"
az feature register --namespace "Microsoft.ContainerService" --name "EnableAzureKeyvaultSecretsProvider"
az feature register --namespace "Microsoft.ContainerService" --name "RunCommandPreview"
az feature register --namespace "Microsoft.ContainerService" --name "AKS-AzureDefender"
az feature register --namespace "Microsoft.ContainerService" --name "EventgridPreview"
az feature register --namespace "Microsoft.ContainerService" --name "EnablePrivateClusterPublicFQDN"
az feature register --namespace "Microsoft.ContainerService" --name "HTTPProxyConfigPreview"
az feature register --namespace "Microsoft.ContainerService" --name "DisableLocalAccountsPreview"


az feature register --name OSABypassMarketplace --namespace Microsoft.ContainerService
az feature register --name AROGA --namespace Microsoft.ContainerService

az feature register --namespace "Microsoft.Network" --name "AllowPrivateEndpoints"
az feature register --namespace "Microsoft.Network" --name "AllowAppGwPublicAndPrivateIpOnSamePort"
az feature register --namespace "Microsoft.Network" --name "AllowApplicationGatewayV2UrlRewrite"
az feature register --namespace "Microsoft.Network" --name "AllowApplicationGatewayPrivateLink"



az feature register --namespace "microsoft.storage" --name "AllowNFSV3"
az feature register --namespace "microsoft.storage" --name "PremiumHns"

az feature register --namespace "Microsoft.RedHatOpenShift" --name "preview"
az feature register --namespace "Microsoft.RedHatOpenShift" --name "PrivateClusters"
az feature register --namespace "Microsoft.RedHatOpenShift" --name "INT-APROVED"
az feature register --namespace "Microsoft.RedHatOpenShift" --name "INT-APPROVED"
az provider register -n "Microsoft.RedHatOpenShift" --wait

az feature register --namespace "Microsoft.Compute" --name "SharedDisksForPremium"

```

Check if the feature is active
```
az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/EnablePrivateClusterPublicFQDNh')].{Name:name,State:properties.state}"
```

Re-register the provider
```
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.storage
az provider register --namespace Microsoft.PolicyInsights

az provider unregister --namespace Microsoft.ContainerService
az provider unregister --namespace Microsoft.Network
az provider unregister --namespace Microsoft.storage
az provider unregister --namespace Microsoft.PolicyInsights
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