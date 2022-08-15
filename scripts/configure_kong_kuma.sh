#!/bin/sh

set -e


KUBE_NAME=$1
KUBE_GROUP=$2

SUBSCRIPTION_ID=$(az account show --query id -o tsv) #subscriptionid
LOCATION=$(az group show -n $KUBE_GROUP --query location -o tsv)
NODE_GROUP=$(az aks show --resource-group $KUBE_GROUP --name $KUBE_NAME --query nodeResourceGroup -o tsv)
AKS_SUBNET_ID=$(az aks show --resource-group $KUBE_GROUP --name $KUBE_NAME --query "agentPoolProfiles[0].vnetSubnetId" -o tsv)
AKS_SUBNET_NAME="aks-5-subnet"
KUBE_ING_SUBNET_NAME="ing-4-subnet"
APP_NAMESPACE="dummy-logger"
SECRET_NAME="mytls-cert-secret"
VAULT_NAME=dzkv$KUBE_NAME 

AKS_CONTROLLER_CLIENT_ID="$(az identity list -g $KUBE_GROUP --query "[?contains(name, '$KUBE_NAME-ctl-id')].clientId" -o tsv)"
AKS_CONTROLLER_RESOURCE_ID="$(az identity list -g $KUBE_GROUP --query "[?contains(name, '$KUBE_NAME-clt-id')].id" -o tsv)"

IP_ID=$(az network public-ip list -g $KUBE_GROUP --query "[?contains(name, 'kongingress')].id" -o tsv)
if [ "$IP_ID" == "" ]; then
    echo "creating ingress ip kongingress"
    az network public-ip create -g $KUBE_GROUP -n kongingress --sku STANDARD --dns-name $KUBE_NAME -o none
    IP_ID=$(az network public-ip show -g $KUBE_GROUP -n kongingress -o tsv --query id)
    IP=$(az network public-ip show -g $KUBE_GROUP -n kongingress -o tsv --query ipAddress)
    DNS=$(az network public-ip show -g $KUBE_GROUP -n kongingress -o tsv --query dnsSettings.fqdn)
    echo "created ip $IP_ID with $IP on $DNS"
    az role assignment create --role "Contributor" --assignee $AKS_CONTROLLER_CLIENT_ID --scope $IP_ID -o none
else
    IP=$(az network public-ip show -g $KUBE_GROUP -n kongingress -o tsv --query ipAddress)
    DNS=$(az network public-ip show -g $KUBE_GROUP -n kongingress -o tsv --query dnsSettings.fqdn)
    echo "AKS $AKS_ID already exists with $IP on $DNS"
fi

if kubectl get namespace ingress; then
  echo -e "Namespace ingress found."
else
  kubectl create namespace ingress
  echo -e "Namespace ingress created."
fi

if kubectl get namespace $APP_NAMESPACE; then
  echo -e "Namespace $APP_NAMESPACE found."
else
  kubectl create namespace $APP_NAMESPACE
  echo -e "Namespace $APP_NAMESPACE created."
fi

sleep 2

kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/logging/dummy-logger/depl-logger.yaml -n $APP_NAMESPACE
#kubectl apply -f logging/dummy-logger/svc-cluster-logger.yaml -n dummy-logger

kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/logging/dummy-logger/svc-cluster-logger.yaml -n $APP_NAMESPACE

# Add the kong repository
helm repo add kong https://charts.konghq.com
helm repo add kuma https://kumahq.github.io/charts

# Update the helm repo(s)
helm repo update
# https://github.com/Kong/charts/blob/main/charts/kong/README.md

# helm upgrade kong-ingress kong/kong --install \
#     --set ingressController.installCRDs=false \
#     --namespace ingress \
#     --set replicaCount=2 \
#     --set proxy.loadBalancerIP="$IP" \
#     --set proxy.externalTrafficPolicy="Local" \
#     --set-string proxy.annotations.'service\.beta\.kubernetes\.io/azure-load-balancer-resource-group'="$KUBE_GROUP" \
#     --set-string proxy.annotations.'service\.beta\.kubernetes\.io/azure-pip-name'="kongingress" \
#     --set autoscaling.enabled=true --wait

helm upgrade kong-ingress kong/kong --install \
    --set ingressController.installCRDs=false \
    --namespace ingress \
    --set replicaCount=2 \
    --set proxy.externalTrafficPolicy="Local" \
    --set-string proxy.annotations.'service\.beta\.kubernetes\.io/azure-load-balancer-internal'="true" \
    --set-string proxy.annotations.'service\.beta\.kubernetes\.io/azure-pls-create'="true" \
    --set-string proxy.annotations.'service\.beta\.kubernetes\.io/azure-pls-name'="internalpls" \
    --set-string proxy.annotations.'service\.beta\.kubernetes\.io/azure-pls-ip-configuration-subnet'="ing-4-subnet" \
    --set-string proxy.annotations.'service\.beta\.kubernetes\.io/azure-pls-proxy-protocol'="false" \
    --set-string proxy.annotations.'service\.beta\.kubernetes\.io/azure-pls-visibility'="*" \
    --set autoscaling.enabled=true --wait

sleep 5


helm upgrade kuma kuma/kuma --create-namespace --namespace kuma-system  --install

#kubectl port-forward svc/kuma-control-plane -n kuma-system 5681:5681

echo "
apiVersion: configuration.konghq.com/v1
kind: KongPlugin
metadata:
  name: request-id
config:
  header_name: my-request-id
plugin: correlation-id
" | kubectl apply -f -

kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: http-$APP_NAMESPACE
  namespace: $APP_NAMESPACE
  annotations:
    konghq.com/plugins: request-id
spec:  
  ingressClassName: kong
  rules:
  - http:
      paths:
      - path: /
        pathType: ImplementationSpecific
        backend:
          service:
            name: dummy-logger
            port:
              number: 80
EOF



kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: https-$APP_NAMESPACE
  namespace: $APP_NAMESPACE
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt
spec:  
  tls:
  - hosts:
    - $DNS
    secretName: $SECRET_NAME
  ingressClassName: nginx
  rules:
  - host: $DNS
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: dummy-logger
            port:
              number: 80
EOF

echo $DNS
