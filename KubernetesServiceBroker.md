# Setting up Service Broker
https://docs.microsoft.com/en-us/azure/aks/integrate-azure

0. Define variables
```
SUBSCRIPTION_ID=""
KUBE_GROUP="kubesaks"
KUBE_NAME="dzkubes"
LOCATION="westeurope"
REGISTRY_NAME=""
APPINSIGHTS_KEY=""
```

Select subscription
```
az account set --subscription $SUBSCRIPTION_ID
```

1. Get available cluster versions

```
az aks get-upgrades --name $KUBE_NAME --resource-group $KUBE_GROUP --output table
```

2. Upgrade cluster to a specific version
```
KUBE_VERSION=1.8.7
az aks upgrade --name $KUBE_NAME --resource-group $KUBE_GROUP --kubernetes-version $KUBE_VERSION
```

3. Verify versions
```
az aks show --name $KUBE_NAME --resource-group $KUBE_GROUP --output table
```

4. Verify at least [helm 2.7.0](Helm.md)
```
helm version
```

5. Install service broker helm charts


