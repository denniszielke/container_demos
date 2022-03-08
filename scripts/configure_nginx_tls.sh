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
SECRET_NAME="mytls-cert-secret"
VAULT_NAME=dzkv$KUBE_NAME 

CERT_MANAGER_REGISTRY=quay.io
CERT_MANAGER_TAG=v1.3.1
CERT_MANAGER_IMAGE_CONTROLLER=jetstack/cert-manager-controller
CERT_MANAGER_IMAGE_WEBHOOK=jetstack/cert-manager-webhook
CERT_MANAGER_IMAGE_CAINJECTOR=jetstack/cert-manager-cainjector

AKS_CONTROLLER_CLIENT_ID="$(az identity list -g $KUBE_GROUP --query "[?contains(name, '$KUBE_NAME-ctl-id')].clientId" -o tsv)"
AKS_CONTROLLER_RESOURCE_ID="$(az identity list -g $KUBE_GROUP --query "[?contains(name, '$KUBE_NAME-clt-id')].id" -o tsv)"

IP_ID=$(az network public-ip list -g $KUBE_GROUP --query "[?contains(name, 'nginxingress')].id" -o tsv)
if [ "$IP_ID" == "" ]; then
    echo "creating ingress ip nginxingress"
    az network public-ip create -g $KUBE_GROUP -n nginxingress --sku STANDARD --dns-name $KUBE_NAME -o none
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

# Install the cert-manager Helm chart
helm upgrade cert-manager jetstack/cert-manager \
  --namespace ingress --install \
  --version $CERT_MANAGER_TAG \
  --set installCRDs=true \
  --set image.repository=$CERT_MANAGER_REGISTRY/$CERT_MANAGER_IMAGE_CONTROLLER \
  --set image.tag=$CERT_MANAGER_TAG \
  --set webhook.image.repository=$CERT_MANAGER_REGISTRY/$CERT_MANAGER_IMAGE_WEBHOOK \
  --set webhook.image.tag=$CERT_MANAGER_TAG \
  --set cainjector.image.repository=$CERT_MANAGER_REGISTRY/$CERT_MANAGER_IMAGE_CAINJECTOR \
  --set cainjector.image.tag=$CERT_MANAGER_TAG --wait --timeout 60s

helm upgrade nginx-ingress ingress-nginx/ingress-nginx --install \
    --namespace ingress \
    --set controller.replicaCount=2 \
    --set controller.metrics.enabled=true \
    --set controller.service.loadBalancerIP="$IP" \
    --set defaultBackend.enabled=true \
    --set-string controller.service.annotations.'service\.beta\.kubernetes\.io/azure-load-balancer-resource-group'="$KUBE_GROUP" \
    --set-string controller.service.annotations.'service\.beta\.kubernetes\.io/azure-pip-name'="nginxingress" \
    --set controller.service.externalTrafficPolicy=Local --wait --timeout 60s

sleep 5

kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: mail@test.de
    privateKeySecretRef:
      name: letsencrypt
    solvers:
    - http01:
        ingress:
          class: nginx
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

exit

OUTPUT=${1:-"$HOME/certificates"}

DOMAIN=$(kubectl get secret -n $APP_NAMESPACE $SECRET_NAME -o json | jq -r '.data."tls.crt"' | base64 -d | openssl x509 -noout -text | grep "Subject: CN=" | sed -E 's/\s+Subject: CN=([^ ]*)/\1/g')
echo -n " ${DOMAIN}"

mkdir -p "${OUTPUT}/${DOMAIN}"

kubectl get secret -n ${APP_NAMESPACE} ${SECRET_NAME} -o json | jq -r '.data."tls.key"' | base64 -d > "${OUTPUT}/${DOMAIN}/privkey.pem"
kubectl get secret -n ${APP_NAMESPACE} ${SECRET_NAME}  -o json | jq -r '.data."tls.crt"' | base64 -d > "${OUTPUT}/${DOMAIN}/fullchain.pem"
#kubectl get secret -n dummy-logger dummy-cert-secret -o json | jq -r '.data."tls.crt"' | base64 -d


openssl pkcs12 -export -in "${OUTPUT}/${DOMAIN}/fullchain.pem" -inkey "${OUTPUT}/${DOMAIN}/privkey.pem" -out "${OUTPUT}/${DOMAIN}/$SECRET_NAME.pfx"


az keyvault certificate import --vault-name ${VAULT_NAME} -n $SECRET_NAME -f "${OUTPUT}/${DOMAIN}/$SECRET_NAME.pfx"

