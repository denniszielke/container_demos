#!/bin/bash

set -e

# infrastructure deployment properties

PROJECT_NAME="$1" # here enter unique deployment name (ideally short and with letters for global uniqueness)
REGISTRY_OWNER="denniszielke"
IMAGE_TAG="latest"
APP_NAMESPACE="calculator"
FRONTEND_NAMESPACE="calculator-frontend"
BACKEND_NAMESPACE="calculator-backend"

if [ "$PROJECT_NAME" == "" ]; then
echo "No project name provided - aborting"
exit 0;
fi

if [[ $PROJECT_NAME =~ ^[a-z0-9]{5,13}$ ]]; then
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

# KUBE_NAME=$(az aks list -g $RESOURCE_GROUP --query '[0].name' -o tsv)

# if [ "$KUBE_NAME" == "" ]; then
#     echo "no AKS cluster found in Resource Group $RESOURCE_GROUP"
#     error=1
# fi

# echo "found cluster $KUBE_NAME"
# echo "getting kubeconfig for cluster $KUBE_NAME"

#az aks get-credentials --resource-group=$RESOURCE_GROUP --name=$KUBE_NAME --admin

# CONTROLLER_ID=$(az aks show -g $RESOURCE_GROUP -n $KUBE_NAME --query identity.principalId -o tsv)
# echo "controller id is $CONTROLLER_ID"
# NODE_GROUP=$(az aks show -g $RESOURCE_GROUP -n $KUBE_NAME --query nodeResourceGroup -o tsv)
 
AI_CONNECTIONSTRING=$(az resource show -g $RESOURCE_GROUP -n appi-$PROJECT_NAME --resource-type "Microsoft.Insights/components" --query properties.ConnectionString -o tsv | tr -d '[:space:]')

echo $AI_CONNECTIONSTRING

replaces="s/{.registry}/$REGISTRY_OWNER/;";
replaces="$replaces s/{.tag}/$IMAGE_TAG/; ";
replaces="$replaces s/{.version}/$IMAGE_TAG/; ";
replaces="$replaces s/{.frontend-namespace}/$FRONTEND_NAMESPACE/; ";
replaces="$replaces s/{.backend-namespace}/$BACKEND_NAMESPACE/; ";
replaces="$replaces s/{.requester-namespace}/$APP_NAMESPACE/; ";


cat ./yaml/depl-calc-backend.yaml | sed -e "$replaces" | kubectl apply -f -
cat ./yaml/depl-calc-frontend.yaml | sed -e "$replaces" | kubectl apply -f -
#cat ./yaml/depl-calc-requester.yaml | sed -e "$replaces" | kubectl apply -f -


# kubectl create secret generic appconfig -n $APP_NAMESPACE \
#    --from-literal=applicationInsightsConnectionString=$AI_CONNECTIONSTRING \
#    --save-config --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic appconfig -n $FRONTEND_NAMESPACE \
   --from-literal=applicationInsightsConnectionString=$AI_CONNECTIONSTRING \
   --save-config --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic appconfig -n $BACKEND_NAMESPACE \
   --from-literal=applicationInsightsConnectionString=$AI_CONNECTIONSTRING \
   --save-config --dry-run=client -o yaml | kubectl apply -f -