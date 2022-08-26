#!/bin/bash

set -e

# infrastructure deployment properties

PROJECT_NAME="$1" # here enter unique deployment name (ideally short and with letters for global uniqueness)
REGISTRY_OWNER="$2"
IMAGE_TAG="$3"

if [ "$PROJECT_NAME" == "" ]; then
echo "No project name provided - aborting"
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
    echo "resource group $RESOURCE_GROUP does not exist"
    error=1
else   
    echo "resource group $RESOURCE_GROUP already exists"
    LOCATION=$(az group show -n $RESOURCE_GROUP --query location -o tsv)
fi

KUBE_NAME=$(az aks list -g $RESOURCE_GROUP --query '[0].name' -o tsv)

if [ "$KUBE_NAME" == "" ]; then
    echo "no AKS cluster found in Resource Group $RESOURCE_GROUP"
    error=1
fi

echo "found cluster $KUBE_NAME"
echo "getting kubeconfig for cluster $KUBE_NAME"

az aks get-credentials --resource-group=$RESOURCE_GROUP --name=$KUBE_NAME --admin

# CONTROLLER_ID=$(az aks show -g $RESOURCE_GROUP -n $KUBE_NAME --query identity.principalId -o tsv)
# echo "controller id is $CONTROLLER_ID"
NODE_GROUP=$(az aks show -g $RESOURCE_GROUP -n $KUBE_NAME --query nodeResourceGroup -o tsv)
 
# IP_ID=$(az network public-ip list -g $NODE_GROUP --query '[?tags."k8s-azure-service"].id' -o tsv)
# IP_NAME=$(az network public-ip list -g $NODE_GROUP --query '[?tags."k8s-azure-service"].name' -o tsv)
# DNS=$(az network public-ip show -g $NODE_GROUP -n $IP_NAME -o tsv --query dnsSettings.fqdn)

# if [ "$DNS" == "" ]; then
#     echo "update ingress ip $NODE_GROUP dns"
#     az network public-ip update -g $NODE_GROUP -n $IP_NAME --dns-name $PROJECT_NAME -o none
#     DNS=$(az network public-ip show -g $NODE_GROUP -n $IP_NAME -o tsv --query dnsSettings.fqdn)
#     echo "update webrouting ip $IP_ID with $IP on $DNS"
# else
#     echo "found webrouting ip $IP on $DNS"
# fi

AI_CONNECTIONSTRING=$(az resource show -g $RESOURCE_GROUP -n appi-$PROJECT_NAME --resource-type "Microsoft.Insights/components" --query properties.ConnectionString -o tsv | tr -d '[:space:]')

# echo $AI_CONNECTIONSTRING
# echo $BLOB_CONNECTIONSTRING
# echo $EVENTHUB_CONNECTIONSTRING
# echo $EVENTHUB_NAME
# echo $COSMOS_CONNECTIONSTRING

kubectl create secret generic appconfig \
   --from-literal=applicationInsightsConnectionString=$AI_CONNECTIONSTRING \
   --save-config --dry-run=client -o yaml | kubectl apply -f -


replaces="s/{.registry}/$REGISTRY_OWNER/;";
replaces="$replaces s/{.tag}/$IMAGE_TAG/; ";
replaces="$replaces s/{.version}/$IMAGE_TAG/; ";

cat ./yaml/depl-calc-backend.yaml | sed -e "$replaces" | kubectl apply -f -
cat ./yaml/depl-calc-frontend.yaml | sed -e "$replaces" | kubectl apply -f -
cat ./yaml/depl-calc-requester.yaml | sed -e "$replaces" | kubectl apply -f -
