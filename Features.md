# AKS features lists

Get AKS features
```
az feature list --namespace Microsoft.ContainerService 

az feature list --namespace  Microsoft.DocumentDB 
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
az feature register --name APIServerSecurityPreview --namespace Microsoft.ContainerService
az feature register --name V20180331API --namespace Microsoft.ContainerService
az feature register --name AksBypassServiceGate --namespace Microsoft.ContainerService
az feature register --name AvailabilityZonePreview --namespace Microsoft.ContainerService
```

Check if the feature is active
az feature list -o table --query "[?contains(name, 'Microsoft.Container‐Service/APIServerSecurityPreview')].{Name:name,State:properties.state}"

Re-register the provider
```
az provider register --namespace Microsoft.ContainerService
```

Install the preview cli
```
az extension add -n aks-preview
```

Get list of clusters
```
az aks list -o table
```

Upgrade a cluster
```
az aks upgrade --resource-group kub_ter_a_m_kwsdemo1 --name kwsdemo1 --kubernetes-version 1.11.4
```