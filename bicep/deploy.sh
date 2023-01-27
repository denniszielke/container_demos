#!/bin/bash

set -e

# infrastructure deployment properties
PROJECT_NAME="$1"
LOCATION="$2"
CONTROLLER_IDENTITY_NAME="$3"
AKS_SUBNET_RESOURCE_ID="$4"
AKS_ADMINGROUP_ID="$5"

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

AKS_CONTROLLER_RESOURCE_ID="$(az identity list -g $RESOURCE_GROUP --query "[?contains(name, '$CONTROLLER_IDENTITY_NAME')].id" -o tsv)"
if [ "$AKS_CONTROLLER_RESOURCE_ID" == "" ]; then
    echo "controller identity $CONTROLLER_IDENTITY_NAME does not exist in resource group $RESOURCE_GROUP"
    exit 0;
else
    echo "controller identity $AKS_CONTROLLER_RESOURCE_ID already exists"
fi

echo "aks subnet $AKS_SUBNET_RESOURCE_ID"

az deployment group create -g $RESOURCE_GROUP -f ./main.bicep -p projectName=$PROJECT_NAME -p controllerIdentity=$AKS_CONTROLLER_RESOURCE_ID -p nodePoolSubnetId=$AKS_SUBNET_RESOURCE_ID -p aksAdminGroupId=$AKS_ADMINGROUP_ID -o none
