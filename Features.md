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
az provider register -n Microsoft.ContainerService
```

Get list of clusters
```
az aks list -o table
```

Upgrade a cluster
```
az aks upgrade --resource-group kub_ter_a_m_kwsdemo1 --name kwsdemo1 --kubernetes-version 1.11.4
```