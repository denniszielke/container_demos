# Create container cluster in a VNET (AKs)
https://docs.microsoft.com/en-us/cli/azure/acs?view=azure-cli-latest#az_acs_create
https://docs.microsoft.com/en-us/azure/aks/networking-overview

0. Variables
```
SUBSCRIPTION_ID=""
KUBE_GROUP="kubenets"
KUBE_NAME="dkubes"
LOCATION="westeurope"
KUBE_VNET_NAME="knets"
KUBE_GW_SUBNET_NAME="gw-1-subnet"
KUBE_ACI_SUBNET_NAME="aci-2-subnet"
KUBE_FW_SUBNET_NAME="fw-3-subnet"
KUBE_ING_SUBNET_NAME="ing-4-subnet"
KUBE_AGENT_SUBNET_NAME="aks-5-subnet"
KUBE_VERSION="1.11.4"
SERVICE_PRINCIPAL_ID=
SERVICE_PRINCIPAL_SECRET=
AAD_APP_NAME=""
AAD_APP_ID=
AAD_APP_SECRET=
AAD_CLIENT_NAME=
AAD_CLIENT_ID=
TENANT_ID=
```

Select subscription
```
az account set --subscription $SUBSCRIPTION_ID
```

1. Create the resource group
```
az group create -n $KUBE_GROUP -l $LOCATION
```

2. Create VNETs
```
az network vnet create -g $KUBE_GROUP -n $KUBE_VNET_NAME 
```

Get available service endpoints
```
az network vnet list-endpoint-services -l $LOCATION
```

Assign permissions on vnet
```
az role assignment create --role "Virtual Machine Contributor" --assignee $SERVICE_PRINCIPAL_ID -g $KUBE_GROUP
az role assignment create --role "Contributor" --assignee $SERVICE_PRINCIPAL_ID -g $KUBE_GROUP
```

Create dns zone
```
az network dns zone create -g $KUBE_GROUP  -n runningcode.local  --zone-type Private --registration-vnets $KUBE_VNET_NAME
```
KUBE_GW_SUBNET_NAME="gw-1-subnet"
KUBE_ACI_SUBNET_NAME="aci-2-subnet"
KUBE_FW_SUBNET_NAME="fw-3-subnet"
KUBE_ING_SUBNET_NAME="ing-4-subnet"
KUBE_AGENT_SUBNET_NAME="aks-5-subnet"
3. Create Subnets
Register azure firewall https://docs.microsoft.com/en-us/azure/firewall/public-preview

```
az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_GW_SUBNET_NAME --address-prefix 10.0.1.0/24
az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_ACI_SUBNET_NAME --address-prefix 10.0.2.0/24 --service-endpoints Microsoft.Sql Microsoft.AzureCosmosDB Microsoft.KeyVault
az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_FW_SUBNET_NAME --address-prefix 10.0.3.0/24
az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_ING_SUBNET_NAME --address-prefix 10.0.4.0/24
az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_AGENT_SUBNET_NAME --address-prefix 10.0.5.0/22 --service-endpoints Microsoft.Sql Microsoft.AzureCosmosDB Microsoft.KeyVault
```

4. Create the aks cluster

get vm sizes
```
az vm list-sizes -l $LOCATION
```

create cluster without rbac
```

KUBE_AGENT_SUBNET_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$KUBE_GROUP/providers/Microsoft.Network/virtualNetworks/$KUBE_VNET_NAME/subnets/$KUBE_AGENT_SUBNET_NAME"

az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --node-count 4  --ssh-key-value ~/.ssh/id_rsa.pub --network-plugin azure --vnet-subnet-id $KUBE_AGENT_SUBNET_ID --docker-bridge-address 172.17.0.1/16 --dns-service-ip 10.2.0.10 --service-cidr 10.2.0.0/24 --client-secret $SERVICE_PRINCIPAL_SECRET --service-principal $SERVICE_PRINCIPAL_ID --kubernetes-version $KUBE_VERSION
```

for additional rbac
```
KUBE_AGENT_SUBNET_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$KUBE_GROUP/providers/Microsoft.Network/virtualNetworks/$KUBE_VNET_NAME/subnets/$KUBE_AGENT_SUBNET_NAME"

az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --node-count 2  --ssh-key-value ~/.ssh/id_rsa.pub --network-plugin azure --vnet-subnet-id $KUBE_AGENT_SUBNET_ID --docker-bridge-address 172.17.0.1/16 --dns-service-ip 10.2.0.10 --service-cidr 10.2.0.0/24 --client-secret $SERVICE_PRINCIPAL_SECRET --service-principal $SERVICE_PRINCIPAL_ID --kubernetes-version $KUBE_VERSION --enable-rbac --aad-server-app-id $AAD_APP_ID --aad-server-app-secret $AAD_APP_SECRET --aad-client-app-id $AAD_CLIENT_ID --aad-tenant-id $TENANT_ID --node-vm-size "Standard_B2s"

az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --node-count 2  --ssh-key-value ~/.ssh/id_rsa.pub --network-plugin azure --vnet-subnet-id $KUBE_AGENT_SUBNET_ID --docker-bridge-address 172.17.0.1/16 --dns-service-ip 10.2.0.10 --service-cidr 10.2.0.0/24 --client-secret $SERVICE_PRINCIPAL_SECRET --service-principal $SERVICE_PRINCIPAL_ID --kubernetes-version $KUBE_VERSION --enable-rbac --node-vm-size "Standard_D2s_v3"

```

with kubenet
```
az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --node-count 2  --ssh-key-value ~/.ssh/id_rsa.pub --network-plugin kubenet --vnet-subnet-id $KUBE_AGENT_SUBNET_ID --docker-bridge-address 172.17.0.1/16 --dns-service-ip 10.2.0.10 --service-cidr 10.2.0.0/24 --client-secret $SERVICE_PRINCIPAL_SECRET --service-principal $SERVICE_PRINCIPAL_ID --kubernetes-version $KUBE_VERSION --enable-rbac --node-vm-size "Standard_D2s_v3"

```

--node-vm-size "Standard_B2s"
--node-vm-size "Standard_D2s_v3"

5. Export the kubectrl credentials files
```
az aks get-credentials --resource-group=$KUBE_GROUP --name=$KUBE_NAME
```

or RBAC
https://github.com/denniszielke/container_demos/blob/master/KubernetesRBAC.md

```
az aks get-credentials --resource-group $KUBE_GROUP --name $KUBE_NAME --admin
```


create addition dns record

az network dns zone list --resource-group $KUBE_GROUP

az network dns record-set list -g $KUBE_GROUP -z runningcode.local

az network dns zone show -g $KUBE_GROUP -n contoso.com -o json


az network dns record-set a add-record \
  -g $KUBE_GROUP \
  -z runningcode.local \
  -n dummy \
  -a 10.0.4.24

curl 10.0.4.24
curl nginx.runningcode.local