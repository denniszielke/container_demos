# AKS Maintenance

Get all upgrade versions
```
az aks get-upgrades --resource-group=$KUBE_GROUP --name=$KUBE_NAME --output table

az aks nodepool get-upgrades  --nodepool-name nodepool2  --resource-group=$KUBE_GROUP --cluster-name=$KUBE_NAME
```


Perform upgrade
```

az aks nodepool show  --resource-group=$KUBE_GROUP --cluster-name=$KUBE_NAME --name nodepool1 --query nodeImageVersion

az aks upgrade --resource-group=$KUBE_GROUP --name=$KUBE_NAME --kubernetes-version 1.22.6

az aks nodepool upgrade --name nodepool2  --resource-group=$KUBE_GROUP --cluster-name=$KUBE_NAME --kubernetes-version 1.22.6

az aks upgrade --resource-group=$KUBE_GROUP --name=$KUBE_NAME --node-image-only

az aks update -g $KUBE_GROUP -n $KUBE_NAME --auto-upgrade-channel stable # patch	stable rapid node-image
az aks update -g $KUBE_GROUP -n $KUBE_NAME --auto-upgrade-channel node-image
```


## Maintenance window


```
az aks maintenanceconfiguration add -g $KUBE_GROUP --cluster-name $KUBE_NAME -n default --weekday Tuesday  --start-hour 12

```
