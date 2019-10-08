# Periscope
https://github.com/Azure/aks-periscope/blob/master/README.md


```
az aks kollect -g $KUBE_GROUP -n $KUBE_NAME

STORAGE_ACCOUNT_KEY=$(az storage account keys list --account-name "dzt$KUBE_NAME" --resource-group $KUBE_GROUP --query "[0].value" | tr -d '"')

az aks kollect -g $KUBE_GROUP -n $KUBE_NAME --storage-account "dzt$KUBE_NAME" --sas-token $STORAGE_ACCOUNT_KEY


az aks kollect -g $KUBE_GROUP -n $KUBE_NAME

```

# Cleanup

```

kubectl delete ds aks-periscope -n aks-periscope 
kubectl delete secret azureblob-secret -n aks-periscope
kubectl delete configmap containerlogs-config -n aks-periscope
kubectl delete configmap kubeobjects-config -n aks-periscope

```