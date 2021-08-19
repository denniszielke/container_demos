#!/bin/sh

#
# wget https://raw.githubusercontent.com/denniszielke/container_demos/master/scripts/aks_vnet.sh
# chmod +x ./aks_vnet.sh
# bash ./aks_vnet.sh
#

set -e

DEPLOYMENT_NAME="dznets" # here enter unique deployment name (ideally short and with letters for global uniqueness)
USE_PRIVATE_LINK="false" # use to deploy private master endpoint
USE_POD_SUBNET="true"

AAD_GROUP_ID="9329d38c-5296-4ecb-afa5-3e74f9abe09f --enable-azure-rbac" # here the AAD group that will be used to lock down AKS authentication
LOCATION="westeurope" #"eastus2euap" #"westeurope" # here enter the datacenter location can be eastus or westeurope
KUBE_GROUP=$DEPLOYMENT_NAME # here enter the resources group name of your AKS cluster
KUBE_NAME=$DEPLOYMENT_NAME # here enter the name of your kubernetes resource
NODE_GROUP=$KUBE_GROUP"_"$KUBE_NAME"_nodes_"$LOCATION # name of the node resource group
KUBE_VNET_NAME="$DEPLOYMENT_NAME-vnet"
KUBE_FW_SUBNET_NAME="AzureFirewallSubnet" # this you cannot change
APPGW_SUBNET_NAME="gw-1-subnet"
KUBE_ING_SUBNET_NAME="ing-4-subnet" # here enter the name of your ingress subnet
KUBE_AGENT_SUBNET_NAME="aks-5-subnet" # here enter the name of your AKS subnet
POD_AGENT_SUBNET_NAME="pod-8-subnet" 
SUBSCRIPTION_ID=$(az account show --query id -o tsv) # here enter your subscription id
TENANT_ID=$(az account show --query tenantId -o tsv)
KUBE_VERSION=$(az aks get-versions -l $LOCATION --query 'orchestrators[?default == `true`].orchestratorVersion' -o tsv) # here enter the kubernetes version of your AKS
KUBE_CNI_PLUGIN="azure"
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

echo "setting up vnet"

VNET_RESOURCE_ID=$(az network vnet list -g $KUBE_GROUP --query "[?contains(name, '$KUBE_VNET_NAME')].id" -o tsv)
if [ "$VNET_RESOURCE_ID" == "" ]; then
    echo "creating vnet $KUBE_VNET_NAME..."
    az network vnet create  --address-prefixes "10.0.0.0/20"  -g $KUBE_GROUP -n $KUBE_VNET_NAME -o none
    az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_FW_SUBNET_NAME --address-prefix 10.0.3.0/24  -o none
    az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $APPGW_SUBNET_NAME --address-prefix 10.0.2.0/24  -o none
    az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_ING_SUBNET_NAME --address-prefix 10.0.4.0/24  -o none
    az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_AGENT_SUBNET_NAME --address-prefix 10.0.5.0/24   -o none
    az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $POD_AGENT_SUBNET_NAME --address-prefix 10.0.8.0/22   -o none
    VNET_RESOURCE_ID=$(az network vnet show -g $KUBE_GROUP -n $KUBE_VNET_NAME --query id -o tsv)
    echo "created $VNET_RESOURCE_ID"
else
    echo "vnet $VNET_RESOURCE_ID already exists"
fi

ROUTE_TABLE_ID=$(az network vnet subnet show -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_AGENT_SUBNET_NAME --query routeTable.id -o tsv)
KUBE_AGENT_SUBNET_ID=$(az network vnet subnet show -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_AGENT_SUBNET_NAME --query id -o tsv)
KUBE_POD_SUBNET_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$KUBE_GROUP/providers/Microsoft.Network/virtualNetworks/$KUBE_VNET_NAME/subnets/$POD_AGENT_SUBNET_NAME"


if [ "$ROUTE_TABLE_ID" == "" ]; then
    echo "could not find routetable on AKS subnet $KUBE_AGENT_SUBNET_ID"
else
    echo "using routetable $ROUTE_TABLE_ID with the following entries"
    ROUTE_TABLE_GROUP=$(az network route-table show --ids $ROUTE_TABLE_ID --query "[resourceGroup]" -o tsv)
    ROUTE_TABLE_NAME=$(az network route-table show --ids $ROUTE_TABLE_ID --query "[name]" -o tsv)
    echo "if this routetable does not contain a route for '0.0.0.0/0' with target VirtualAppliance or VirtualNetworkGateway then we will not need the outbound type parameter"
    az network route-table route list --resource-group $ROUTE_TABLE_GROUP --route-table-name $ROUTE_TABLE_NAME -o table
    echo "if it does not contain a '0.0.0.0/0' route then you should set the parameter IGNORE_FORCE_ROUTE=true"
    if [ "$IGNORE_FORCE_ROUTE" == "true" ]; then
        echo "ignoring forced tunneling route information"
        OUTBOUNDTYPE=""
    else
        echo "using forced tunneling route information"
        OUTBOUNDTYPE=" --outbound-type userDefinedRouting "
    fi
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
    sleep 25 # wait for replication
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

echo "setting up aks"
AKS_ID=$(az aks list -g $KUBE_GROUP --query "[?contains(name, '$KUBE_NAME')].id" -o tsv)

if [ "$USE_PRIVATE_LINK" == "true" ]; then
    ACTIVATE_PRIVATE_LINK=" --enable-private-cluster "
else
    ACTIVATE_PRIVATE_LINK=""
fi

if [ "$AKS_ID" == "" ]; then
    echo "creating AKS $KUBE_NAME in $KUBE_GROUP"
    echo "using host subnet $KUBE_AGENT_SUBNET_ID"
    if [ "$USE_POD_SUBNET" == "true" ]; then
        echo "using pod subnet $KUBE_POD_SUBNET_ID"
        az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME$AKS_POSTFIX --ssh-key-value ~/.ssh/id_rsa.pub  --max-pods 250 --node-count 3 --min-count 3 --max-count 5 --enable-cluster-autoscaler --node-resource-group $NODE_GROUP --load-balancer-sku standard --enable-vmss  --network-plugin azure --vnet-subnet-id $KUBE_AGENT_SUBNET_ID --pod-subnet-id $KUBE_POD_SUBNET_ID --docker-bridge-address 172.17.0.1/16 --dns-service-ip 10.2.0.10 --service-cidr 10.2.0.0/24 --kubernetes-version $KUBE_VERSION --assign-identity $AKS_CONTROLLER_RESOURCE_ID --node-osdisk-size 300 --enable-managed-identity --enable-aad --aad-admin-group-object-ids $AAD_GROUP_ID --aad-tenant-id $TENANT_ID $ACTIVATE_PRIVATE_LINK --network-policy calico -o none
    else
        az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME$AKS_POSTFIX --ssh-key-value ~/.ssh/id_rsa.pub  --node-count 3 --node-vm-size "Standard_B2s" --min-count 3 --max-count 5 --enable-cluster-autoscaler --node-resource-group $NODE_GROUP --load-balancer-sku standard --enable-vmss  --network-plugin azure --vnet-subnet-id $KUBE_AGENT_SUBNET_ID --docker-bridge-address 172.17.0.1/16 --dns-service-ip 10.2.0.10 --service-cidr 10.2.0.0/24 --kubernetes-version $KUBE_VERSION --assign-identity $AKS_CONTROLLER_RESOURCE_ID --node-osdisk-size 300 --enable-managed-identity --enable-aad --aad-admin-group-object-ids $AAD_GROUP_ID --aad-tenant-id $TENANT_ID $ACTIVATE_PRIVATE_LINK --network-policy calico -o none
    fi
    #az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --ssh-key-value ~/.ssh/id_rsa.pub  --node-count 3 --min-count 3  --node-vm-size "Standard_D2s_v3" --max-count 5 --enable-cluster-autoscaler --node-resource-group $NODE_GROUP --load-balancer-sku standard --enable-vmss --node-osdisk-type Ephemeral  --network-plugin azure --vnet-subnet-id $KUBE_AGENT_SUBNET_ID --docker-bridge-address 172.17.0.1/16 --dns-service-ip 10.2.0.10 --service-cidr 10.2.0.0/24 --kubernetes-version $KUBE_VERSION --no-ssh-key --assign-identity $AKS_CONTROLLER_RESOURCE_ID --node-osdisk-size 30 --enable-managed-identity --enable-aad --aad-admin-group-object-ids $AAD_GROUP_ID --aad-tenant-id $TENANT_ID --uptime-sla $OUTBOUNDTYPE $ACTIVATE_PRIVATE_LINK -o none
    az aks update --resource-group $KUBE_GROUP --name $KUBE_NAME --auto-upgrade-channel node-image
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
    OMS_CLIENT_ID=$(az aks show -g $KUBE_GROUP -n $KUBE_NAME --query addonProfiles.omsagent.identity.clientId -o tsv)
    az role assignment create --assignee $OMS_CLIENT_ID --scope $AKS_ID --role "Monitoring Metrics Publisher"
fi

IP_ID=$(az network public-ip list -g $NODE_GROUP --query "[?contains(name, 'nginxingress')].id" -o tsv)
if [ "$IP_ID" == "" ]; then
    echo "creating ingress ip nginxingress"
    az network public-ip create -g $NODE_GROUP -n nginxingress --sku STANDARD -o none
    IP_ID=$(az network public-ip show -g $NODE_GROUP -n nginxingress -o tsv)
    echo "created ip $IP_ID"
    IP=$(az network public-ip show -g $NODE_GROUP -n nginxingress -o tsv --query ipAddress)
else
    echo "AKS $AKS_ID already exists"
    IP=$(az network public-ip show -g $NODE_GROUP -n nginxingress -o tsv --query ipAddress)
fi

VAULT_NAME=dva$KUBE_NAME
SECRET_NAME="mySecret"
VAULT_ID=$(az keyvault list -g $KUBE_GROUP --query "[?contains(name, '$VAULT_NAME')].id" -o tsv)
if [ "$VAULT_ID" == "" ]; then
    echo "creating keyvault $VAULT_NAME"
    az keyvault create -g $KUBE_GROUP -n $VAULT_NAME -l $LOCATION -o none
    az keyvault secret set -n $SECRET_NAME --vault-name $VAULT_NAME --value MySuperSecretThatIDontWantToShareWithYou! -o none
    az aks enable-addons --resource-group="$KUBE_GROUP" --name="$KUBE_NAME" --addons="azure-keyvault-secrets-provider"
    az aks update --resource-group="$KUBE_GROUP" --name="$KUBE_NAME" --enable-secret-rotation
    VAULT_ID=$(az keyvault show -g $KUBE_GROUP -n $VAULT_NAME -o tsv --query id)
    echo "created keyvault $VAULT_ID"
else
    echo "keyvault $VAULT_ID already exists"
    VAULT_ID=$(az keyvault show -g $KUBE_GROUP -n $VAULT_NAME -o tsv --query name)
fi

az aks get-credentials --resource-group=$KUBE_GROUP --name=$KUBE_NAME --admin

echo "created this AKS cluster:"

az aks show  --resource-group=$KUBE_GROUP --name=$KUBE_NAME
