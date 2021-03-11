# AKS Maintenance

Get all upgrade versions
```
az aks get-upgrades --resource-group=$KUBE_GROUP --name=$KUBE_NAME --output table
```


Perform upgrade
```
az aks upgrade --resource-group=$KUBE_GROUP --name=$KUBE_NAME --kubernetes-version 1.10.6
az aks update -g $KUBE_GROUP -n $KUBE_NAME --auto-upgrade-channel stable # patch	stable rapid
```


## Maintenance window


```
az aks maintenanceconfiguration add -g $KUBE_GROUP --cluster-name $KUBE_NAME -n default --weekday Tuesday  --start-hour 12

```
