#!/bin/bash

set -e

# infrastructure deployment properties
PROJECT_NAME="$1"
LOCATION="$2"
CONTROLLER_IDENTITY_NAME="$3"

if [ "$PROJECT_NAME" == "" ]; then
echo "No project name provided - aborting"
exit 0;
fi

if [ "$LOCATION" == "" ]; then
echo "No location provided - aborting"
exit 0;
fi

if [[ $PROJECT_NAME =~ ^[a-z0-9]{5,9}$ ]]; then
    echo "project name $PROJECT_NAME is valid"
else
    echo "project name $PROJECT_NAME is invalid - only numbers and lower case min 5 and max 8 characters allowed - aborting"
    exit 0;
fi

RESOURCE_GROUP="$PROJECT_NAME"

AZURE_CORE_ONLY_SHOW_ERRORS="True"

if [ $(az group exists --name $RESOURCE_GROUP) = false ]; then
    echo "creating resource group $RESOURCE_GROUP..."
    az group create -n $RESOURCE_GROUP -l $LOCATION -o none
    echo "resource group $RESOURCE_GROUP created"
else   
    echo "resource group $RESOURCE_GROUP already exists"
    LOCATION=$(az group show -n $RESOURCE_GROUP --query location -o tsv)
fi

echo "setting up vnet"

KUBE_VNET_NAME="$PROJECT_NAME-vnet"
KUBE_ING_SUBNET_NAME="$PROJECT_NAME-ingress"
AKS_SUBNET_NAME="$PROJECT_NAME-aks"
VNET_RESOURCE_ID=$(az network vnet list -g $RESOURCE_GROUP --query "[?contains(name, '$KUBE_VNET_NAME')].id" -o tsv)
if [ "$VNET_RESOURCE_ID" == "" ]; then
    echo "creating vnet $KUBE_VNET_NAME..."
    az network vnet create  --address-prefixes "10.0.0.0/24"  -g $RESOURCE_GROUP -n $KUBE_VNET_NAME -o none
    az network vnet subnet create -g $RESOURCE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_ING_SUBNET_NAME --address-prefix 10.0.0.0/28 -o none
    az network vnet subnet create -g $RESOURCE_GROUP --vnet-name $KUBE_VNET_NAME -n $AKS_SUBNET_NAME --address-prefix 10.0.0.32/27 -o none
   
    VNET_RESOURCE_ID=$(az network vnet show -g $RESOURCE_GROUP -n $KUBE_VNET_NAME --query id -o tsv)
    echo "created $VNET_RESOURCE_ID"
else
    echo "vnet $VNET_RESOURCE_ID already exists"
fi

NSG_RESOURCE_ID=$(az network nsg list -g $RESOURCE_GROUP --query "[?contains(name, '$AKS_SUBNET_NAME')].id" -o tsv)
if [ "$NSG_RESOURCE_ID" == "" ]; then
    echo "creating nsgs..."

    az network nsg create --name $KUBE_ING_SUBNET_NAME --resource-group $RESOURCE_GROUP --location $LOCATION

    az network nsg rule create --name appgwrule --nsg-name $KUBE_ING_SUBNET_NAME --resource-group $RESOURCE_GROUP --priority 110 \
    --source-address-prefixes '*' --source-port-ranges '*' \
    --destination-address-prefixes '*' --destination-port-ranges 80 443 --access Allow --direction Inbound \
    --protocol "*" --description "Required allow rule for Ingress."

    KUBE_ING_SUBNET_NSG=$(az network nsg show -g $RESOURCE_GROUP -n $KUBE_ING_SUBNET_NAME --query id -o tsv)
    KUBE_ING_SUBNET_ID=$(az network vnet subnet show -g $RESOURCE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_ING_SUBNET_NAME --query id -o tsv)
    az network vnet subnet update --resource-group $RESOURCE_GROUP --network-security-group $KUBE_ING_SUBNET_NSG --ids $KUBE_ING_SUBNET_ID
    echo "attached nsg to subnet $KUBE_ING_SUBNET_ID"

    az network nsg create --name $AKS_SUBNET_NAME --resource-group $RESOURCE_GROUP --location $LOCATION

    az network nsg rule create --name ingress --nsg-name $AKS_SUBNET_NAME --resource-group $RESOURCE_GROUP --priority 110 \
    --source-address-prefixes '*' --source-port-ranges '*' \
    --destination-address-prefixes '*' --destination-port-ranges 80 443 --access Allow --direction Inbound \
    --protocol "*" --description "Required to allow ingress."

    KUBE_AGENT_SUBNET_NSG=$(az network nsg show -g $RESOURCE_GROUP -n $AKS_SUBNET_NAME --query id -o tsv)
    KUBE_AGENT_SUBNET_ID=$(az network vnet subnet show -g $RESOURCE_GROUP --vnet-name $KUBE_VNET_NAME -n $AKS_SUBNET_NAME --query id -o tsv)
    az network vnet subnet update --resource-group $RESOURCE_GROUP --network-security-group $KUBE_AGENT_SUBNET_NSG --ids $KUBE_AGENT_SUBNET_ID
    echo "attached nsg to subnet $KUBE_AGENT_SUBNET_ID"
    echo "cread nsgs "
else
    echo "nsg $NSG_RESOURCE_ID already exists"
fi
KUBE_ING_SUBNET_ID=$(az network vnet subnet show -g $RESOURCE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_ING_SUBNET_NAME --query id -o tsv)
KUBE_AGENT_SUBNET_ID=$(az network vnet subnet show -g $RESOURCE_GROUP --vnet-name $KUBE_VNET_NAME -n $AKS_SUBNET_NAME --query id -o tsv)

AKS_CONTROLLER_RESOURCE_ID="$(az identity list -g $RESOURCE_GROUP --query "[?contains(name, '$CONTROLLER_IDENTITY_NAME')].id" -o tsv)"
if [ "$AKS_CONTROLLER_RESOURCE_ID" == "" ]; then
    echo "controller identity $CONTROLLER_IDENTITY_NAME does not exist in resource group $RESOURCE_GROUP - creating..."
    az identity create --name $CONTROLLER_IDENTITY_NAME --resource-group $RESOURCE_GROUP -o none
    sleep 10 # wait for replication
    AKS_CONTROLLER_CLIENT_ID="$(az identity show -g $RESOURCE_GROUP -n $CONTROLLER_IDENTITY_NAME --query clientId -o tsv)"
    AKS_CONTROLLER_RESOURCE_ID="$(az identity show -g $RESOURCE_GROUP -n $CONTROLLER_IDENTITY_NAME --query id -o tsv)"
    echo "created controller identity $AKS_CONTROLLER_RESOURCE_ID "
    echo "assigning permissions on network $KUBE_AGENT_SUBNET_ID"
    sleep 20 # wait for replication
    AKS_CONTROLLER_CLIENT_ID="$(az identity show -g $RESOURCE_GROUP -n $CONTROLLER_IDENTITY_NAME --query clientId -o tsv)"
    AKS_CONTROLLER_RESOURCE_ID="$(az identity show -g $RESOURCE_GROUP -n $CONTROLLER_IDENTITY_NAME --query id -o tsv)"
    echo "created controller identity $AKS_CONTROLLER_RESOURCE_ID "
    echo "assigning permissions on network $KUBE_AGENT_SUBNET_ID"
    sleep 20 # wait for replication
    az role assignment create --role "Network Contributor" --assignee $AKS_CONTROLLER_CLIENT_ID --scope $KUBE_AGENT_SUBNET_ID -o none
    az role assignment create --role "Network Contributor" --assignee $AKS_CONTROLLER_CLIENT_ID --scope $KUBE_ING_SUBNET_ID -o none
else
    echo "controller identity $AKS_CONTROLLER_RESOURCE_ID already exists"
fi

