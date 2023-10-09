# AKS features lists

Get AKS features
```
az feature list --namespace Microsoft.ContainerService -o table
az feature list --namespace Microsoft.ContainerRegistry -o table
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
az feature list --namespace Microsoft.Dashboard -o table
az feature list --namespace Microsoft.ServiceNetworking -o table
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
az feature register --namespace "Microsoft.ContainerService" --name "AKS-ScaleDownModePreview"
az feature register --namespace "Microsoft.ContainerService" --name "AKS-NATGatewayPreview"
az feature register --namespace "Microsoft.ContainerService" --name "AKS-Dapr"
az feature register --namespace "Microsoft.ContainerService" --name "PreviewStartStopAgentPool"
az feature register --namespace "Microsoft.ContainerService" --name "EnableMultipleStandardLoadBalancers"
az feature register --namespace "Microsoft.ContainerService" --name "EnablePodIdentityPreview"
az feature register --namespace "Microsoft.ContainerService" --name "EnableOIDCIssuerPreview"
az feature register --namespace "Microsoft.ContainerService" --name "PreviewGuardRails"
az feature register --namespace "Microsoft.ContainerService" --name "EnableNamespaceResourcesPreview"
az feature register --namespace "Microsoft.ContainerService" --name "FleetResourcePreview"
az feature register --namespace "Microsoft.ContainerService" --name "SnapshotPreview"
az feature register --namespace "Microsoft.ContainerService" --name "HTTP-Application-Routing"
az feature register --namespace "Microsoft.ContainerService" --name "AKS-KedaPreview"
az feature register --namespace "Microsoft.ContainerService" --name "AKSARM64Preview"
az feature register --namespace "Microsoft.ContainerService" --name "EnableBlobCSIDriver"
az feature register --namespace "Microsoft.ContainerService" --name "EnableImageCleanerPreview"
az feature register --namespace "Microsoft.ContainerService" --name "FleetResourcePreview"
az feature register --namespace "Microsoft.ContainerService" --name "KubeProxyConfigurationPreview"
az feature register --namespace "Microsoft.ContainerService" --name "CiliumDataplanePreview"
az feature register --namespace "Microsoft.ContainerService" --name "WasmNodePoolPreview"
az feature register --namespace "Microsoft.ContainerService" --name "EnablePrivateClusterSubZone"
az feature register --namespace "Microsoft.ContainerService" --name "EnableWorkloadIdentityPreview"
az feature register --namespace "Microsoft.ContainerService" --name "EnableAzureDiskCSIDriverV2"
az feature register --namespace "Microsoft.ContainerService" --name "AzureOverlayPreview"
az feature register --namespace "Microsoft.ContainerService" --name "AKS-PrometheusAddonPreview"
az feature register --namespace "Microsoft.ContainerService" --name "KataVMIsolationPreview"
az feature register --namespace "Microsoft.ContainerService" --name "AutoUpgradePreview"
az feature register --namespace "Microsoft.ContainerService" --name "AKS-ExtensionManager"
az feature register --namespace "Microsoft.ContainerService" --name "AKSNodelessPreview"
az feature register --namespace "Microsoft.ContainerService" --name "AKS-ExtensionManager"
az feature register --namespace "Microsoft.ContainerService" --name "CiliumDataplanePreview"
az feature register --namespace "Microsoft.ContainerService" --name "EnableAPIServerVnetIntegrationPreview" 
az feature register --namespace "Microsoft.ContainerService" --name "NRGLockdownPreview" 
az feature register --namespace "Microsoft.ContainerService" --name "AzureServiceMeshPreview" 
az feature register --namespace "Microsoft.ContainerService" --name "NodeOsUpgradeChannelPreview" 
az feature register --namespace "Microsoft.ContainerService" --name "NetworkObservabilityPreview" 
az feature register --namespace "Microsoft.ContainerService" --name "AKSLockingDownEgressPreview" 
az feature register --namespace "Microsoft.ContainerService" --name "GuardrailsPreview" 
az feature register --namespace "Microsoft.ContainerService" --name "ClusterCostAnalysis"

az feature list --namespace Microsoft.ContainerService -o table

az feature register --name PrivatePreview --namespace Microsoft.Dashboard

az feature list --namespace Microsoft.Network -o table
az feature register --namespace "Microsoft.Network" --name "AllowPrivateEndpoints"
az feature register --namespace "Microsoft.Network" --name "AllowAppGwPublicAndPrivateIpOnSamePort"
az feature register --namespace "Microsoft.Network" --name "AllowApplicationGatewayV2UrlRewrite"
az feature register --namespace "Microsoft.Network" --name "AllowApplicationGatewayPrivateLink"
az feature register --namespace "Microsoft.Network" --name "AllowApplicationGatewayRelaxedOutboundRestrictions"
az feature register --namespace "Microsoft.Network" --name "AllowApplicationGatewayLoadDistributionPolicy"

az feature list --namespace Microsoft.App -o table
az feature register --namespace "microsoft.app" --name "ServerlessCompute"
az feature register --namespace "microsoft.app" --name "PrereleaseApiVersionAllowed"
az feature register --namespace "microsoft.app" --name "WorkloadProfiles"

az feature register --namespace "microsoft.storage" --name "AllowNFSV3"
az feature register --namespace "microsoft.storage" --name "PremiumHns"

az feature register --namespace "Microsoft.RedHatOpenShift" --name "preview"
az feature register --namespace "Microsoft.RedHatOpenShift" --name "PrivateClusters"
az feature register --namespace "Microsoft.RedHatOpenShift" --name "INT-APROVED"
az feature register --namespace "Microsoft.RedHatOpenShift" --name "INT-APPROVED"
az provider register -n "Microsoft.RedHatOpenShift" --wait

az feature register --namespace "Microsoft.Compute" --name "SharedDisksForPremium"

az feature list --namespace Microsoft.ServiceNetworking -o table
az feature register --namespace "Microsoft.ServiceNetworking" --name "AllowTrafficController"

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
az provider register --namespace Microsoft.Insights
az provider register --namespace Microsoft.AlertsManagement
az provider register --namespace Microsoft.OperationsManagement
az provider register --namespace Microsoft.ServiceNetworking
az provider register --namespace Microsoft.EventGrid
 
az provider show -n Microsoft.ServiceNetworking

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