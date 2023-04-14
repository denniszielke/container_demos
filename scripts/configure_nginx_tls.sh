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
APP_NAMESPACE="dummy-logger"
SECRET_NAME="nginx-cert-secret"
VAULT_NAME=dzkv$KUBE_NAME 

AKS_CONTROLLER_CLIENT_ID="$(az identity list -g $KUBE_GROUP --query "[?contains(name, '$KUBE_NAME-ctl-id')].clientId" -o tsv)"
AKS_CONTROLLER_RESOURCE_ID="$(az identity list -g $KUBE_GROUP --query "[?contains(name, '$KUBE_NAME-clt-id')].id" -o tsv)"

IP_ID=$(az network public-ip list -g $KUBE_GROUP --query "[?contains(name, 'nginxingress')].id" -o tsv)
if [ "$IP_ID" == "" ]; then
    echo "creating ingress ip nginxingress"
    az network public-ip create -g $KUBE_GROUP -n nginxingress --sku STANDARD --dns-name n$KUBE_NAME -o none
    IP_ID=$(az network public-ip show -g $KUBE_GROUP -n nginxingress -o tsv --query id)
    IP=$(az network public-ip show -g $KUBE_GROUP -n nginxingress -o tsv --query ipAddress)
    DNS=$(az network public-ip show -g $KUBE_GROUP -n nginxingress -o tsv --query dnsSettings.fqdn)
    echo "created ip $IP_ID with $IP on $DNS"
    az role assignment create --role "Contributor" --assignee $AKS_CONTROLLER_CLIENT_ID --scope $IP_ID -o none
else
    IP=$(az network public-ip show -g $KUBE_GROUP -n nginxingress -o tsv --query ipAddress)
    DNS=$(az network public-ip show -g $KUBE_GROUP -n nginxingress -o tsv --query dnsSettings.fqdn)
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

# Add the ingress-nginx repository
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add jetstack https://charts.jetstack.io

# Update the helm repo(s)
helm repo update


# helm upgrade cert-manager jetstack/cert-manager \
#   --namespace ingress --install \
#   --set installCRDs=true  --wait

helm upgrade nginx-ingress ingress-nginx/ingress-nginx --install \
    --namespace ingress \
    --set controller.replicaCount=2 \
    --set controller.metrics.enabled=true \
    --set controller.service.loadBalancerIP="$IP" \
    --set defaultBackend.enabled=true \
    --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz  \
    --set-string controller.service.annotations.'service\.beta\.kubernetes\.io/azure-load-balancer-resource-group'="$KUBE_GROUP" \
    --set-string controller.service.annotations.'service\.beta\.kubernetes\.io/azure-pip-name'="nginxingress" \
    --set controller.service.externalTrafficPolicy=Local #\
    #--set-string controller.podAnnotations.'linkerd\.io/inject'="enabled" --wait

sleep 5

kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt
  namespace: cert-manager
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: mail@test.de
    privateKeySecretRef:
      name: letsencrypt
    solvers:
    - http01:
        ingress:
          class: webapprouting.kubernetes.azure.com
EOF

sleep 5

kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: https-$APP_NAMESPACE
  namespace: $APP_NAMESPACE
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt
    nginx.ingress.kubernetes.io/service-upstream: "true"
    nginx.ingress.kubernetes.io/rewrite-target: /
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