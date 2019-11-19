# VHD
https://github.com/Azure/aks-engine/blob/master/docs/howto/troubleshooting.md



vmss 429
https://github.com/Azure/aks-engine/issues/1860
https://github.com/Azure/AKS/issues/1278

az vmss update-instances -g <RESOURCE_GROUP_NAME> --name <VMSS_NAME> --instance-id <ID(number)>



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

# Logs

Relevant logs:
/var/log/azure/cluster-provision.log
/var/log/cloud-init-output.log
/var/log/azure/custom-script/handler.log
/opt/azure/provision-ps.log

Provision script log output:
/var/log/azure/cluster-provision.log

Exit code from:
/opt/azure/provision-ps.log

See script run times:
/opt/m

Look up exit error codes:
https://github.com/Azure/aks-engine/blob/master/parts/k8s/cloud-init/artifacts/cse_helpers.sh


# TCP dump
https://github.com/digeler/k8tcpappend