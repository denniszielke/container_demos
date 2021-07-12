# VHD
https://github.com/Azure/aks-engine/blob/master/docs/howto/troubleshooting.md



vmss 429
https://github.com/Azure/aks-engine/issues/1860
https://github.com/Azure/AKS/issues/1278

az vmss update-instances -g <RESOURCE_GROUP_NAME> --name <VMSS_NAME> --instance-id <ID(number)>

# enter ssh

sudo wget https://raw.githubusercontent.com/andyzhangx/demo/master/dev/kubectl-enter

sudo chmod a+x ./kubectl-enter

./kubectl-enter <node-name>

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
/var/log/waagent.log

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


# Diagnostics


# Set your Azure virtual machine scale set diagnostic variables.

```
KUBE_GROUP=
KUBE_NAME=
LOCATION=$(az group show -n $KUBE_GROUP --query location -o tsv)
NODE_GROUP=$(az aks show --resource-group $KUBE_GROUP --name $KUBE_NAME --query nodeResourceGroup -o tsv)
SCALE_SET_NAME=$(az vmss list --resource-group $NODE_GROUP --query "[0].name" -o tsv)
az storage account create --resource-group $NODE_GROUP --name $KUBE_NAME --location $LOCATION --sku Standard_LRS --access-tier hot --https-only false

az vmss identity assign -g $NODE_GROUP -n $SCALE_SET_NAME

wget https://raw.githubusercontent.com/Azure/azure-linux-extensions/master/Diagnostic/tests/lad_2_3_compatible_portal_pub_settings.json -O portal_public_settings.json

my_vmss_resource_id=$(az vmss show -g $NODE_GROUP -n $SCALE_SET_NAME --query "id" -o tsv)
sed -i "s#__DIAGNOSTIC_STORAGE_ACCOUNT__#$KUBE_NAME#g" portal_public_settings.json
sed -i "s#__VM_RESOURCE_ID__#$my_vmss_resource_id#g" portal_public_settings.json

my_diagnostic_storage_account_sastoken=$(az storage account generate-sas --account-name $KUBE_NAME --expiry 2037-12-31T23:59:00Z --permissions wlacu --resource-types co --services bt -o tsv)
my_lad_protected_settings="{'storageAccountName': '$KUBE_NAME', 'storageAccountSasToken': '$my_diagnostic_storage_account_sastoken'}"


az vmss extension set --publisher Microsoft.Azure.Diagnostics --name LinuxDiagnostic --version 4.0 --resource-group $NODE_GROUP --vmss-name $SCALE_SET_NAME --protected-settings "${my_lad_protected_settings}" --settings portal_public_settings.json
```