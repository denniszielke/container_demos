# AKS Engine
https://github.com/Azure/aks-engine/blob/master/docs/topics/clusterdefinitions.md

0. Variables
```
SUBSCRIPTION_ID=""
KUBE_GROUP="akse444"
VNET_GROUP="aksengine"
KUBE_NAME="dz-aks444"
LOCATION="westeurope"
SERVICE_PRINCIPAL_ID=""
SERVICE_PRINCIPAL_SECRET=""
KUBE_VNET_NAME=aksvnet
VM_VNET_NAME=vmnet
KUBE_MASTER_SUBNET_NAME="m-1-subnet"
KUBE_WORKER_SUBNET_NAME="w-2-subnet"
KUBE_POD_SUBNET_NAME="p-3-subnet"
YOUR_SSH_KEY=$(cat ~/.ssh/id_rsa.pub)
```

# Get aks-engine tools

Download latest release from https://github.com/Azure/aks-engine/releases

```
wget https://github.com/Azure/aks-engine/releases/download/v0.43.2/aks-engine-v0.43.2-darwin-amd64.tar.gz 
tar -zxvf aks-engine-v0.43.2-darwin-amd64.tar.gz 
cd aks-engine-v0.43.2-darwin-amd64
```

# Create Identity
```
SP_NAME="$KUBE_NAME-sp"

SERVICE_PRINCIPAL_ID=$(az ad sp create-for-rbac --skip-assignment --name $SP_NAME -o json | jq -r '.appId')
echo $SERVICE_PRINCIPAL_ID

SERVICE_PRINCIPAL_SECRET=$(az ad app credential reset --id $SERVICE_PRINCIPAL_ID -o json | jq '.password' -r)
echo $SERVICE_PRINCIPAL_SECRET
```

# Prepare variables

1. Download config file from https://github.com/denniszielke/container_demos/blob/master/aks-engine/acseng.json

Check config
https://github.com/Azure/aks-engine/blob/master/docs/topics/clusterdefinitions.md

Replace `SERVICE_PRINCIPAL_ID`, `SERVICE_PRINCIPAL_SECRET` and `YOUR_SSH_KEY` with your own values

```
sed -e "s/SERVICE_PRINCIPAL_ID/$SERVICE_PRINCIPAL_ID/ ; s/SERVICE_PRINCIPAL_SECRET/$SERVICE_PRINCIPAL_SECRET/ ; s/SUBSCRIPTION_ID/$SUBSCRIPTION_ID/ ; s/KUBE_GROUP/$KUBE_GROUP/ ; s/GROUP_ID/$GROUP_ID/" acseng.json > acseng_out.json
```

2. Replace YOUR_SSH_KEY with your ssh key

# Create VNET

```
az group create -n $VNET_GROUP -l $LOCATION
az network vnet create -g $VNET_GROUP -n $KUBE_VNET_NAME --address-prefixes 172.16.0.0/16 10.240.0.0/16
az network vnet subnet create -g $VNET_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_MASTER_SUBNET_NAME --address-prefix 172.16.1.0/24
az network vnet subnet create -g $VNET_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_WORKER_SUBNET_NAME --address-prefix 172.16.2.0/24 
az network vnet subnet create -g $VNET_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_POD_SUBNET_NAME --address-prefix 10.240.0.0/16

az network vnet create -g $VNET_GROUP -n $VM_VNET_NAME --address-prefixes 10.241.0.0/16 --subnet-name $VM_VNET_NAME --subnet-prefix 10.241.0.0/24

az network vnet peering create -g $VNET_GROUP -n KubeToVMPeer --vnet-name $KUBE_VNET_NAME --remote-vnet $VM_VNET_NAME --allow-vnet-access

az network vnet peering create -g $VNET_GROUP -n VMToKubePeer --vnet-name $VM_VNET_NAME --remote-vnet $KUBE_VNET_NAME --allow-vnet-access
```

# Generate aks-engine

```
./aks-engine generate akseng-sp.json
```

# Deploy cluster

1. Create the resource group and role assignment
```
az group create -n $KUBE_GROUP -l $LOCATION

az role assignment create --role "Contributor" --assignee $SERVICE_PRINCIPAL_ID -g $KUBE_GROUP

az identity create -g $KUBE_GROUP -n dzaksemsi

MSI_CLIENT_ID=$(az identity show -n dzaksemsi -g $KUBE_GROUP --query clientId -o tsv)
az role assignment create --role "Network Contributor" --assignee $MSI_CLIENT_ID -g $VNET_GROUP
az role assignment create --role "Contributor" --assignee $MSI_CLIENT_ID -g $KUBE_GROUP # will be done by aks-engine
```

2. Create cluster
```
az group deployment create \
    --name $KUBE_NAME \
    --resource-group $KUBE_GROUP \
    --template-file "_output/$KUBE_NAME/azuredeploy.json" \
    --parameters "_output/$KUBE_NAME/azuredeploy.parameters.json" --no-wait
```

# assign permissions for smsi

```
SCALE_SET_NAME=$(az vmss list --resource-group $KUBE_GROUP --query '[].{Name:name}' -o tsv)
MSI_CLIENT_ID=$(az vmss identity show --name $SCALE_SET_NAME -g $KUBE_GROUP --query principalId -o tsv)

az role assignment create --role "Network Contributor" --assignee $MSI_CLIENT_ID -g $VNET_GROUP
az role assignment create --role "Contributor" --assignee $MSI_CLIENT_ID -g $VNET_GROUP

VNET_RESOURCE_ID=$(az network vnet show -g $VNET_GROUP -n $KUBE_VNET_NAME --query id -o tsv)
az role assignment create --role "Network Contributor" --assignee $MSI_CLIENT_ID --scope $VNET_RESOURCE_ID
```

# Fix routetable
```
ROUTETABLE_ID=$(az resource list --resource-group $KUBE_GROUP --resource-type Microsoft.Network/routeTables --query '[].{ID:id}' -o tsv)
az network vnet subnet update -n $KUBE_WORKER_SUBNET_NAME -g $VNET_GROUP --vnet-name $KUBE_VNET_NAME --route-table $ROUTETABLE_ID
```

# Load kube config
```
export KUBECONFIG=`pwd`/_output/$KUBE_NAME/kubeconfig/kubeconfig.$LOCATION.json


```

# Delete everything
```
az group delete -n $KUBE_GROUP
```
```
./aks-engine get-versions
```
# Upgrade
The kubeadm configuration is also accessible by standard kubectl ConfigMap interrogation and is, by convention, named the cluster-info ConfigMap in the kube-public namespace.

```
./aks-engine get-versions --version 1.11.5

EXPECTED_ORCHESTRATOR_VERSION=1.11.10

./aks-engine upgrade --debug \
  --subscription-id $SUBSCRIPTION_ID \
  --deployment-dir ../_output/$KUBE_NAME \
  --api-model ../_output/$KUBE_NAME/apimodel.json \
  --location $LOCATION \
  --resource-group $KUBE_GROUP \
  --upgrade-version $EXPECTED_ORCHESTRATOR_VERSION \
  --auth-method client_secret \
  --client-id $SERVICE_PRINCIPAL_ID \
  --client-secret $SERVICE_PRINCIPAL_SECRET

./aks-engine scale --subscription-id $SUBSCRIPTION_ID \
    --resource-group $KUBE_GROUP  --location $LOCATION \
    --client-id $SERVICE_PRINCIPAL_ID \
    --client-secret $SERVICE_PRINCIPAL_SECRET \
    --api-model  _output/$KUBE_NAME/apimodel.json --new-node-count 4 \
    --node-pool agentpool2 --master-FQDN $KUBE_NAME.$LOCATION.cloudapp.azure.com

  ./aks-engine upgrade --debug \
  --subscription-id $SUBSCRIPTION_ID \
  --deployment-dir ../acs-engine-v0.18.8-darwin-amd64/_output/$KUBE_NAME/ \
  --location $LOCATION \
  --resource-group $KUBE_GROUP \
  --upgrade-version $EXPECTED_ORCHESTRATOR_VERSION \
  --auth-method client_secret \
  --client-id $SERVICE_PRINCIPAL_ID \
  --client-secret $SERVICE_PRINCIPAL_SECRET
```

# Upgrade credentials
https://github.com/Azure/aks-engine/issues/724#issuecomment-403183388

```
CLUSTER_RESOURCE_GROUP=acsaksupgrade
SCALE_SET_NAME=aks-default-47461129-vmss


az vmss extension list --resource-group $CLUSTER_RESOURCE_GROUP --vmss-name $SCALE_SET_NAME

az vmss extension show --name vmssCSE --resource-group $CLUSTER_RESOURCE_GROUP --vmss-name $SCALE_SET_NAME --output json

az vm get-instance-view \
    --resource-group $CLUSTER_RESOURCE_GROUP \
    --name k8s-agentpool1-86714434-vmss_0 \
    --query "instanceView.extensions"

  az vmss extension set --name customScript \
    --resource-group $CLUSTER_RESOURCE_GROUP \
    --vmss-name $SCALE_SET_NAME \
    --provision-after-extensions "vmssCSE" \
    --publisher Microsoft.Azure.Extensions --version 2.0 \
    --protected-settings '{"fileUris": ["https://raw.githubusercontent.com/denniszielke/container_demos/master/arm/cse.sh"],"commandToExecute": "./cse.sh"}'

az vmss extension set --vmss-name my-vmss --name customScript --resource-group my-group \
    --version 2.0 --publisher Microsoft.AKS \
    --settings '{"commandToExecute": "echo testing"}'

  az vmss extension set --name customScript \
    --resource-group $CLUSTER_RESOURCE_GROUP \
    --vmss-name $SCALE_SET_NAME \
    --publisher Microsoft.AKS --version 1.0 \
    --protected-settings '{"fileUris": ["https://raw.githubusercontent.com/denniszielke/container_demos/master/arm/cse.sh"],"commandToExecute": "./cse.sh"}'

 az vmss extension set --name CustomScriptForLinux \
    --resource-group $CLUSTER_RESOURCE_GROUP \
    --provisionAfterExtensions "vmssCSE" \
    --vmss-name $SCALE_SET_NAME \
    --publisher Microsoft.OSTCExtensions \
    --settings '{"fileUris": ["https://raw.githubusercontent.com/denniszielke/container_demos/master/arm/cse.sh"],"commandToExecute": "./cse.sh"}'
```

# Troubleshooting
https://github.com/Azure/aks-engine/blob/master/docs/howto/troubleshooting.md


# Restarting as part of extension

mkdir ~/msifix
echo $(date +"%T") >> ~/msifix/out.log
sleep 100
echo $(date +"%T") >> ~/msifix/out.log
kubectl get pod -n kube-system >> ~/msifix/out.log
echo $(date +"%T") >> ~/msifix/out.log
PODNAME=$(kubectl -n kube-system get pod -l "component=kube-controller-manager" -o jsonpath='{.items[0].metadata.name}')
kubectl -n kube-system delete pod $PODNAME >> ~/msifix/out.log
kubectl get pod -n kube-system >> ~/msifix/out.log
echo $(date +"%T") >> ~/msifix/out.log

# Removing LBs

az network lb list -g $KUBE_GROUP

LB_NAME=$KUBE_GROUP
LB_GROUP=$KUBE_GROUP

az network lb rule list --lb-name $LB_NAME --resource-group $LB_GROUP

az network lb outbound-rule list --lb-name $LB_NAME -g $LB_GROUP     

az network lb outbound-rule delete --lb-name $LB_NAME -g $LB_GROUP -n $LB_NAME

az network lb outbound-rule delete --lb-name $LB_NAME -g $LB_GROUP -n LBOutboundRule   

az network lb rule list --lb-name $LB_NAME --resource-group $LB_GROUP

az network lb delete -g $LB_GROUP -n $LB_NAME

az network lb rule list --lb-name $LB_NAME --resource-group $LB_GROUP

az network lb probe list --lb-name $LB_NAME --resource-group $LB_GROUP

az network lb address-pool list --lb-name $LB_NAME --resource-group $LB_GROUP

az network lb address-pool delete --lb-name $LB_NAME --name $LB_NAME --resource-group $LB_GROUP

# Add new LB

LB_GROUP=aksengine
LB_NAME=standardload
IP_NAME=newip

/etc/kubernetes/azure.json
    "loadBalancerResourceGroup": "aksengine",
    "loadBalancerName": "standardload",

az network lb address-pool create --resource-group $LB_GROUP --lb-name $LB_NAME --name LBOutboundRule

az network lb frontend-ip create --resource-group $LB_GROUP --name LoadBalancerFrontEnd --lb-name $LB_NAME --public-ip-address $IP_NAME 

az network lb rule create \
--resource-group myresourcegroupoutbound \
--lb-name lb \
--name inboundlbrule \
--protocol tcp \
--frontend-port 80 \
--backend-port 80 \
--probe http \
--frontend-ip-name myfrontendinbound \
--backend-pool-name bepoolinbound \
--disable-outbound-snat

az network lb rule update --disable-outbound-snat

az network lb outbound-rule create \
 --resource-group $LB_GROUP \
 --lb-name $LB_NAME \
 --name outbound \
 --frontend-ip-configs LoadBalancerFrontEnd \
 --protocol All \
 --idle-timeout 15 \
 --outbound-ports 10000 \
 --address-pool LBOutboundRule