# Create container cluster in a VNET (AKs)
https://docs.microsoft.com/en-us/cli/azure/acs?view=azure-cli-latest#az_acs_create

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

```
az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_FW_SUBNET_NAME --address-prefix 10.0.0.0/24
az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_AGENT_SUBNET_NAME --address-prefix 10.0.4.0/22 --service-endpoints Microsoft.Sql Microsoft.AzureCosmosDB Microsoft.KeyVault
```

4. Create the aks cluster
```
az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --node-count 3  --ssh-key-value ~/.ssh/id_rsa.pub --network-plugin azure --vnet-subnet-id $KUBE_AGENT_SUBNET_NAME --docker-bridge-address 172.17.0.1/16 --dns-service-ip 10.2.0.10 --service-cidr 10.2.0.0/24 --client-secret $SERVICE_PRINCIPAL_SECRET --service-principal $SERVICE_PRINCIPAL_ID --kubernetes-version $KUBE_VERSION

```

