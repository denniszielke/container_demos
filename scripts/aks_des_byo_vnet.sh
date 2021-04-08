#!/bin/sh

#
# wget https://raw.githubusercontent.com/denniszielke/container_demos/master/scripts/aks_des_byo_vnet.sh
# chmod +x ./aks_des_byo_vnet.sh
# bash ./aks_des_byo_vnet.sh
#

set -e
# sudo nano /etc/environment
# http_proxy=http://192.168.43.100:3128/\nhttps_proxy=https://192.168.43.100:3128/
# sudo nano /etc/ntp.conf

SUBSCRIPTION_ID=$(az account show --query id -o tsv) # here enter your subscription id
DEPLOYMENT_NAME="dzciti38" # here enter unique deployment name (ideally short and with letters for global uniqueness)
LOCATION="westeurope" # here enter the datacenter location
KUBE_VNET_GROUP="networks" # here enter the vnet resource group
KUBE_VNET_NAME="hub1-firewalvnet" # here enter the name of your AKS vnet
KUBE_AGENT_SUBNET_NAME="jumpbox-subnet" # here enter the name of your AKS subnet
IGNORE_FORCE_ROUTE="true" # only set to true if you have a routetable on the AKS subnet but that routetable does not contain  a route for '0.0.0.0/0' with target VirtualAppliance or VirtualNetworkGateway
USE_PRIVATE_LINK="false" # use to deploy private master endpoint
AAD_GROUP_ID="9329d38c-5296-4ecb-afa5-3e74f9abe09f" # here the AAD group that will be used to lock down AKS authentication
KUBE_VERSION="$(az aks get-versions -l $LOCATION --query 'orchestrators[?default == `true`].orchestratorVersion' -o tsv)" # here enter the kubernetes version of your AKS or leave this and it will select the latest stable version
TENANT_ID=$(az account show --query tenantId -o tsv) # azure tenant id
KUBE_GROUP=$DEPLOYMENT_NAME # here enter the resources group name of your AKS cluster
KUBE_NAME=$DEPLOYMENT_NAME # here enter the name of your kubernetes resource
NODE_GROUP=$KUBE_GROUP"_"$KUBE_NAME"_nodes_"$LOCATION # name of the node resource group
MY_OWN_OBJECT_ID=$(az ad signed-in-user show --query objectId --output tsv) # this will be your own aad object id
OUTBOUNDTYPE=""

az account set --subscription $SUBSCRIPTION_ID

az extension add --name aks-preview
az extension update --name aks-preview 

if [ $(az group exists --name $KUBE_GROUP) = false ]; then
    echo "creating resource group $KUBE_GROUP..."
    az group create -n $KUBE_GROUP -l $LOCATION -o none
    echo "resource group $KUBE_GROUP created"
else   
    echo "resource group $KUBE_GROUP already exists"
fi

KUBE_AGENT_SUBNET_ID=$(az network vnet subnet show -g $KUBE_VNET_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_AGENT_SUBNET_NAME --query id -o tsv)

if [ "$KUBE_AGENT_SUBNET_ID" == "" ]; then
    echo "could not find subnet $KUBE_AGENT_SUBNET_NAME in vnet $KUBE_VNET_NAME in $KUBE_VNET_GROUP"
    exit 
else
    echo "using subnet $KUBE_AGENT_SUBNET_ID"
fi

ROUTE_TABLE_ID=$(az network vnet subnet show -g $KUBE_VNET_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_AGENT_SUBNET_NAME --query routeTable.id -o tsv)

if [ "$ROUTE_TABLE_ID" == "" ]; then
    echo "could not find routetable on AKS subnet $KUBE_AGENT_SUBNET_ID"
else
    echo "using routetable $ROUTE_TABLE_ID with the following entries"
    ROUTE_TABLE_GROUP=$(az network route-table show --ids $ROUTE_TABLE_ID --query "[resourceGroup]" -o tsv)
    ROUTE_TABLE_NAME=$(az network route-table show --ids $ROUTE_TABLE_ID --query "[name]" -o tsv)
    echo "if this routetable does not contain a route for '0.0.0.0/0' with target VirtualAppliance or VirtualNetworkGateway then we will not need the outbound type parameter"
    az network route-table route list --resource-group $ROUTE_TABLE_GROUP --route-table-name $ROUTE_TABLE_NAME -o table
    echo "if it does not contain a '0.0.0.0/0' route then you should set the parameter IGNORE_FORCE_ROUTE=true"

    echo "adding routes for microsoft container registry"
    az network route-table route create --resource-group $ROUTE_TABLE_GROUP --name "mcr" --route-table-name $ROUTE_TABLE_NAME --address-prefix MicrosoftContainerRegistry --next-hop-type Internet
    echo "adding routes for active directory"
    az network route-table route create --resource-group $ROUTE_TABLE_GROUP --name "aad" --route-table-name $ROUTE_TABLE_NAME --address-prefix AzureActiveDirectory --next-hop-type Internet
    echo "adding routes for azure monitor"
    az network route-table route create --resource-group $ROUTE_TABLE_GROUP --name "monitor" --route-table-name $ROUTE_TABLE_NAME --address-prefix AzureMonitor --next-hop-type Internet
    echo "adding routes for azure region $LOCATION"
    az network route-table route create --resource-group $ROUTE_TABLE_GROUP --name "azure" --route-table-name $ROUTE_TABLE_NAME --address-prefix AzureCloud.$LOCATION --next-hop-type Internet

    if [ "$IGNORE_FORCE_ROUTE" == "true" ]; then
        echo "ignoring forced tunneling route information"
        OUTBOUNDTYPE=""
    else
        echo "using forced tunneling route information"
        OUTBOUNDTYPE=" --outbound-type userDefinedRouting "
    fi
fi

echo "setting up keyvault"

KEYVAULT_ID=$(az keyvault list --query "[?contains(name, '$KUBE_NAME')].id" -o tsv)
if [ "$KEYVAULT_ID" == "" ]; then
    echo "creating keyvault $KUBE_NAME in resource group $KUBE_GROUP..."
    az keyvault create -n $KUBE_NAME -g $KUBE_GROUP -l $LOCATION  --enable-purge-protection true --enable-soft-delete true -o none
    KEYVAULT_ID=$(az keyvault show --name $KUBE_NAME --query "[id]" -o tsv)
    echo "created keyvault $KEYVAULT_ID"
else   
    echo "keyvault $KEYVAULT_ID already exists"
fi

KEYVAULT_URL=$(az keyvault key list --vault-name $KUBE_NAME --query "[?contains(name, 'des')].kid" -o tsv)
if [ "$KEYVAULT_URL" == "" ]; then
    echo "creating key des in  $KUBE_NAME in resource group $KUBE_GROUP..."
    az keyvault key create -n des --vault-name $KUBE_NAME --kty RSA --ops encrypt decrypt wrapKey unwrapKey sign verify --size 2048 -o none
    KEYVAULT_URL=$(az keyvault key show --vault-name $KUBE_NAME  --name des  --query "[key.kid]" -o tsv)
    echo "created keyvault kes $KEYVAULT_URL"
else   
    KEYVAULT_URL=$(az keyvault key show --vault-name $KUBE_NAME  --name des  --query "[key.kid]" -o tsv)
    echo "key des in keyvault $KEYVAULT_URL already exists"
fi

echo "setting up disk encryption set"

DES_ID=$(az disk-encryption-set list -g $KUBE_GROUP --query "[?contains(name, '$KUBE_NAME')].id" -o tsv)
if [ "$DES_ID" == "" ]; then
    echo "creating disk encryption set $KUBE_NAME"
    az disk-encryption-set create -n $KUBE_NAME  -l $LOCATION  -g $KUBE_GROUP --source-vault $KEYVAULT_ID --key-url $KEYVAULT_URL -o none
    sleep 5
    DES_IDENTITY=$(az disk-encryption-set show -n $KUBE_NAME  -g $KUBE_GROUP --query "[identity.principalId]" -o tsv)
    az keyvault set-policy -n $KUBE_NAME -g $KUBE_GROUP --object-id $DES_IDENTITY --key-permissions wrapkey unwrapkey get -o none
    DES_ID=$(az disk-encryption-set show -n $KUBE_NAME -g $KUBE_GROUP --query "[id]" -o tsv)
    DES_IDENTITY=$(az disk-encryption-set show -n $KUBE_NAME  -g $KUBE_GROUP --query "[identity.principalId]" -o tsv)
    echo "created disk encryption set $DES_ID"
else
    echo "disk encryption set $DES_ID already exists"
fi

echo "setting up controller identity"
AKS_CLIENT_ID="$(az identity list -g $KUBE_GROUP --query "[?contains(name, '$KUBE_NAME-id')].clientId" -o tsv)"
AKS_CONTROLLER_RESOURCE_ID="$(az identity list -g $KUBE_GROUP --query "[?contains(name, '$KUBE_NAME-id')].id" -o tsv)"
if [ "$AKS_CLIENT_ID" == "" ]; then
    echo "creating controller identity $KUBE_NAME-id in $KUBE_GROUP"
    az identity create --name $KUBE_NAME-id --resource-group $KUBE_GROUP -o none
    sleep 5 # wait for replication
    AKS_CLIENT_ID="$(az identity show -g $KUBE_GROUP -n $KUBE_NAME-id  --query clientId -o tsv)"
    sleep 5 # wait for replication
    AKS_CLIENT_ID="$(az identity show -g $KUBE_GROUP -n $KUBE_NAME-id  --query clientId -o tsv)"
    AKS_CONTROLLER_RESOURCE_ID="$(az identity show -g $KUBE_GROUP -n $KUBE_NAME-id  --query id -o tsv)"
    echo "created controller identity $AKS_CONTROLLER_RESOURCE_ID "
    echo "assigning permissions on network $KUBE_AGENT_SUBNET_ID"
    sleep 5 # wait for replication
    az role assignment create --role "Contributor" --assignee $AKS_CLIENT_ID --scope $KUBE_AGENT_SUBNET_ID -o none
    if [ "$ROUTE_TABLE_ID" == "" ]; then
        echo "no route table used"
    else
        echo "assigning permissions on routetable $ROUTE_TABLE_ID"
        az role assignment create --role "Contributor" --assignee $AKS_CLIENT_ID --scope $ROUTE_TABLE_ID -o none
    fi
else
    echo "controller identity $AKS_CONTROLLER_RESOURCE_ID already exists"
    echo "assigning permissions on network $KUBE_AGENT_SUBNET_ID"
    az role assignment create --role "Contributor" --assignee $AKS_CLIENT_ID --scope $KUBE_AGENT_SUBNET_ID -o none
    if [ "$ROUTE_TABLE_ID" == "" ]; then
        echo "no route table used"
    else
        echo "assigning permissions on routetable $ROUTE_TABLE_ID"
        az role assignment create --role "Contributor" --assignee $AKS_CLIENT_ID --scope $ROUTE_TABLE_ID -o none
    fi
fi

echo "setting up azure container registry"
ACR_ID="$(az acr list -g $KUBE_GROUP --query "[?contains(name, '$KUBE_NAME')].id" -o tsv)"
if [ "$ACR_ID" == "" ]; then
    echo "creating ACR $KUBE_NAME in $KUBE_GROUP"
    az acr create --resource-group $KUBE_GROUP --name $KUBE_NAME --sku Standard --location $LOCATION -o none
    ACR_ID="$(az acr show -g $KUBE_GROUP -n $KUBE_NAME  --query id -o tsv)"
    echo "created ACR $ACR_ID"
else
    echo "ACR $ACR_ID already exists"
fi

echo "setting up aks"
AKS_ID=$(az aks list -g $KUBE_GROUP --query "[?contains(name, '$KUBE_NAME')].id" -o tsv)

if [ "$USE_PRIVATE_LINK" == "true" ]; then
    ACTIVATE_PRIVATE_LINK=" --enable-private-cluster "
else
    ACTIVATE_PRIVATE_LINK=""
fi

if [ "$AKS_ID" == "" ]; then
    echo "creating AKS $KUBE_NAME in $KUBE_GROUP"
    az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --ssh-key-value ~/.ssh/id_rsa.pub  --node-count 3 --min-count 3 --max-count 5 --enable-cluster-autoscaler --node-resource-group $NODE_GROUP --load-balancer-sku standard --enable-vmss  --network-plugin kubenet --vnet-subnet-id $KUBE_AGENT_SUBNET_ID --docker-bridge-address 172.17.0.1/16 --dns-service-ip 10.2.0.10 --service-cidr 10.2.0.0/24 --kubernetes-version $KUBE_VERSION --no-ssh-key --assign-identity $AKS_CONTROLLER_RESOURCE_ID --node-osdisk-size 300 --node-osdisk-diskencryptionset-id $DES_ID --enable-managed-identity  --enable-aad --aad-admin-group-object-ids $AAD_GROUP_ID --aad-tenant-id $TENANT_ID --uptime-sla --attach-acr $ACR_ID $OUTBOUNDTYPE $ACTIVATE_PRIVATE_LINK -o none
    AKS_ID=$(az aks show -g $KUBE_GROUP -n $KUBE_NAME --query id -o tsv)
    echo "created AKS $AKS_ID"
else
    echo "AKS $AKS_ID already exists"
fi

echo "setting up azure monitor"

WORKSPACE_RESOURCE_ID=$(az monitor log-analytics workspace list --resource-group $KUBE_GROUP --query "[?contains(name, '$KUBE_NAME')].id" -o tsv)
if [ "$WORKSPACE_RESOURCE_ID" == "" ]; then
    echo "creating workspace $KUBE_NAME in $KUBE_GROUP"
    az monitor log-analytics workspace create --resource-group $KUBE_GROUP --workspace-name $KUBE_NAME --location $LOCATION -o none
    WORKSPACE_RESOURCE_ID=$(az monitor log-analytics workspace show --resource-group $KUBE_GROUP --workspace-name $KUBE_NAME -o json | jq '.id' -r)
    az aks enable-addons --resource-group $KUBE_GROUP --name $KUBE_NAME --addons monitoring --workspace-resource-id $WORKSPACE_RESOURCE_ID
fi

az aks get-credentials --resource-group=$KUBE_GROUP --name=$KUBE_NAME
