# Create container cluster in a VNET (AKs)
https://docs.microsoft.com/en-us/cli/azure/acs?view=azure-cli-latest#az_acs_create
https://docs.microsoft.com/en-us/azure/aks/networking-overview

0. Variables
```
SUBSCRIPTION_ID=""
KUBE_GROUP="kubevnet"
KUBE_NAME="dzkubenet"
LOCATION="westeurope"
KUBE_VNET_NAME="KVNET"
KUBE_AGENT_SUBNET_NAME="AKSAGENTS"
KUBE_FW_SUBNET_NAME="FWNET"
KUBE_VERSION="1.10.5"
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
```

3. Create Subnets
Register azure firewall https://docs.microsoft.com/en-us/azure/firewall/public-preview

```
az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_FW_SUBNET_NAME --address-prefix 10.0.0.0/24
az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n "AzureFirewallSubnet" --address-prefix 10.0.1.0/24
az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_AGENT_SUBNET_NAME --address-prefix 10.0.4.0/22 --service-endpoints Microsoft.Sql Microsoft.AzureCosmosDB Microsoft.KeyVault
```

4. Create the aks cluster
```
KUBE_AGENT_SUBNET_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$KUBE_GROUP/providers/Microsoft.Network/virtualNetworks/$KUBE_VNET_NAME/subnets/$KUBE_AGENT_SUBNET_NAME"
az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --node-count 3  --ssh-key-value ~/.ssh/id_rsa.pub --network-plugin azure --vnet-subnet-id $KUBE_AGENT_SUBNET_ID --docker-bridge-address 172.17.0.1/16 --dns-service-ip 10.2.0.10 --service-cidr 10.2.0.0/24 --client-secret $SERVICE_PRINCIPAL_SECRET --service-principal $SERVICE_PRINCIPAL_ID --kubernetes-version $KUBE_VERSION

```

for additional rbac
```
KUBE_AGENT_SUBNET_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$KUBE_GROUP/providers/Microsoft.Network/virtualNetworks/$KUBE_VNET_NAME/subnets/$KUBE_AGENT_SUBNET_NAME"
az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --node-count 3  --ssh-key-value ~/.ssh/id_rsa.pub --network-plugin azure --vnet-subnet-id $KUBE_AGENT_SUBNET_ID --docker-bridge-address 172.17.0.1/16 --dns-service-ip 10.2.0.10 --service-cidr 10.2.0.0/24 --client-secret $SERVICE_PRINCIPAL_SECRET --service-principal $SERVICE_PRINCIPAL_ID --kubernetes-version $KUBE_VERSION --enable-rbac --aad-server-app-id $AAD_APP_ID --aad-server-app-secret $AAD_APP_SECRET --aad-client-app-id $AAD_CLIENT_ID --aad-tenant-id $TENANT_ID
```

5. Export the kubectrl credentials files
```
az aks get-credentials --resource-group=$KUBE_GROUP --name=$KUBE_NAME
```

or RBAC
https://github.com/denniszielke/container_demos/blob/master/KubernetesRBAC.md

```
az aks get-credentials --resource-group $KUBE_GROUP --name $KUBE_NAME --admin
```

