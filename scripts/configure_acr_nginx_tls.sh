#!/bin/sh

set -e


KUBE_NAME=$1
KUBE_GROUP=$2
USE_ADDON=$3

SUBSCRIPTION_ID=$(az account show --query id -o tsv) #subscriptionid
LOCATION=$(az group show -n $KUBE_GROUP --query location -o tsv)
NODE_GROUP=$(az aks show --resource-group $KUBE_GROUP --name $KUBE_NAME --query nodeResourceGroup -o tsv)
AKS_SUBNET_ID=$(az aks show --resource-group $KUBE_GROUP --name $KUBE_NAME --query "agentPoolProfiles[0].vnetSubnetId" -o tsv)
AKS_SUBNET_NAME="aks-5-subnet"
KUBE_ING_SUBNET_NAME="ing-4-subnet"

CERT_MANAGER_REGISTRY=quay.io
CERT_MANAGER_TAG=v1.3.1
CERT_MANAGER_IMAGE_CONTROLLER=jetstack/cert-manager-controller
CERT_MANAGER_IMAGE_WEBHOOK=jetstack/cert-manager-webhook
CERT_MANAGER_IMAGE_CAINJECTOR=jetstack/cert-manager-cainjector

IP_ID=$(az network public-ip list -g $NODE_GROUP --query "[?contains(name, 'nginxingress')].id" -o tsv)
if [ "$IP_ID" == "" ]; then
    echo "creating ingress ip nginxingress"
    az network public-ip create -g $NODE_GROUP -n nginxingress --sku STANDARD -o none
    IP_ID=$(az network public-ip show -g $NODE_GROUP -n nginxingress -o tsv)
    echo "created ip $IP_ID"
    IP=$(az network public-ip show -g $NODE_GROUP -n nginxingress -o tsv --query ipAddress)
else
    IP=$(az network public-ip show -g $NODE_GROUP -n nginxingress -o tsv --query ipAddress)
    echo "IP $IP_ID already exists with $IP"
fi

KUBELET_ID=$(az aks show -g $KUBE_GROUP -n $KUBE_NAME --query identityProfile.kubeletidentity.clientId -o tsv)
ACR_ID=$(az acr show -n $REGISTRY_NAME --query id -o tsv)

ROLE_ID=$(az role assignment list --scope $ACR_ID --query "[?contains(description, '$KUBELET_ID')].id" -o tsv)
if [ "$ROLE_ID" == "" ]; then
  echo "assigning acrpull for $KUBELET_ID"
  az role assignment create --role acrpull --assignee $KUBELET_ID --scope $ACR_ID --description "$KUBELET_ID"
else
  echo "role assignment for $KUBELET_ID already present"
fi

IMAGES_PRESENT=$(az acr repository show -n $REGISTRY_NAME --image $CONTROLLER_IMAGE:$CONTROLLER_TAG --query name -o tsv)
if [ "$IMAGES_PRESENT" == "" ]; then
  echo "importing images into registry $REGISTRY_NAME"
  az acr import --name $REGISTRY_NAME --source $CONTROLLER_REGISTRY/$CONTROLLER_IMAGE:$CONTROLLER_TAG --image $CONTROLLER_IMAGE:$CONTROLLER_TAG
  az acr import --name $REGISTRY_NAME --source $PATCH_REGISTRY/$PATCH_IMAGE:$PATCH_TAG --image $PATCH_IMAGE:$PATCH_TAG
  az acr import --name $REGISTRY_NAME --source $DEFAULTBACKEND_REGISTRY/$DEFAULTBACKEND_IMAGE:$DEFAULTBACKEND_TAG --image $DEFAULTBACKEND_IMAGE:$DEFAULTBACKEND_TAG
else
  echo "images already in registry $REGISTRY_NAME"
fi

if kubectl get namespace ingress-basic; then
  echo -e "Namespace ingress-basic found."
else
  kubectl create namespace ingress-basic
  echo -e "Namespace ingress-basic created."
fi

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
ACR_URL=$REGISTRY_NAME.azurecr.io
helm upgrade nginx-ingress ingress-nginx/ingress-nginx --install \
    --namespace ingress-basic \
    --set controller.replicaCount=2 \
    --set controller.nodeSelector."kubernetes\.io/os"=linux \
    --set controller.image.registry=$ACR_URL \
    --set controller.image.image=$CONTROLLER_IMAGE \
    --set controller.image.tag=$CONTROLLER_TAG \
    --set controller.service.externalTrafficPolicy=Local \
    --set controller.service.loadBalancerIP="$IP" \
    --set controller.image.digest="" \
    --set controller.metrics.enabled=true \
    --set controller.autoscaling.enabled=true \
    --set controller.admissionWebhooks.patch.nodeSelector."kubernetes\.io/os"=linux \
    --set controller.admissionWebhooks.patch.image.registry=$ACR_URL \
    --set controller.admissionWebhooks.patch.image.image=$PATCH_IMAGE \
    --set controller.admissionWebhooks.patch.image.tag=$PATCH_TAG \
    --set controller.admissionWebhooks.patch.image.digest="" 
    # --set defaultBackend.nodeSelector."kubernetes\.io/os"=linux \
    # --set defaultBackend.enabled=true \ 
    # --set defaultBackend.image.registry=$ACR_URL \
    # --set defaultBackend.image.image=$DEFAULTBACKEND_IMAGE \
    # --set defaultBackend.image.tag=$DEFAULTBACKEND_TAG \
    # --set defaultBackend.image.digest="" 