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

IP_ID=$(az network public-ip list -g $KUBE_GROUP --query "[?contains(name, 'nginxingressauth')].id" -o tsv)
if [ "$IP_ID" == "" ]; then
    echo "creating ingress ip nginxingressauth"
    az network public-ip create -g $KUBE_GROUP -n nginxingressauth --sku STANDARD --dns-name $KUBE_NAME-auth -o none
    IP_ID=$(az network public-ip show -g $KUBE_GROUP -n nginxingressauth -o tsv --query id)
    IP=$(az network public-ip show -g $KUBE_GROUP -n nginxingressauth -o tsv --query ipAddress)
    DNS=$(az network public-ip show -g $KUBE_GROUP -n nginxingressauth -o tsv --query dnsSettings.fqdn)
    echo "created ip $IP_ID with $IP on $DNS"
    az role assignment create --role "Contributor" --assignee $AKS_CONTROLLER_CLIENT_ID --scope $IP_ID -o none
else
    IP=$(az network public-ip show -g $KUBE_GROUP -n nginxingressauth -o tsv --query ipAddress)
    DNS=$(az network public-ip show -g $KUBE_GROUP -n nginxingressauth -o tsv --query dnsSettings.fqdn)
    echo "AKS $AKS_ID already exists with $IP on $DNS"
fi

helm upgrade nginx-ingress-auth ingress-nginx/ingress-nginx --install \
    --namespace ingress-auth \
    --set controller.replicaCount=1 \
    --set controller.metrics.enabled=true \
    --set controller.service.loadBalancerIP="$IP" \
    --set defaultBackend.enabled=true \
    --set controller.ingressClassByName=true \
    --set controller.ingressClassResource.name=nginx-auth \
    --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz  \
    --set-string controller.service.annotations.'service\.beta\.kubernetes\.io/azure-load-balancer-resource-group'="$KUBE_GROUP" \
    --set-string controller.service.annotations.'service\.beta\.kubernetes\.io/azure-pip-name'="nginxingressauth" \
    --set controller.service.externalTrafficPolicy=Local --wait --timeout 60s

exit



export CERT_NAME=ingresscert
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -out ingress-tls.crt \
    -keyout ingress-tls.key \
    -subj "/CN=dzallincl-auth.westeurope.cloudapp.azure.com/O=ingress-tls"

openssl pkcs12 -export -in ingress-tls.crt -inkey ingress-tls.key  -out $CERT_NAME.pfx

az keyvault certificate import --vault-name ${VAULT_NAME} -n $SECRET_NAME -f "$CERT_NAME.pfx"


cat <<EOF | kubectl apply -f -
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: azure-tls
spec:
  provider: azure
  secretObjects:                            # secretObjects defines the desired state of synced K8s secret objects
  - secretName: ingress-tls-csi
    type: kubernetes.io/tls
    data: 
    - objectName: $CERT_NAME
      key: tls.key
    - objectName: $CERT_NAME
      key: tls.crt
  parameters:
    usePodIdentity: "false"
    useVMManagedIdentity: "true"
    userAssignedIdentityID: "$AKS_KUBELET_CLIENT_ID"
    keyvaultName: $AKV_NAME                 # the name of the KeyVault
    objects: |
      array:
        - |
          objectName: $CERT_NAME
          objectType: secret
    tenantId: $TENANT_ID                    # the tenant ID of the KeyVault
EOF

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

# register aad app

AD_APP_NAME="dzallincl"
TLS_SECRET_NAME=$APP_HOSTNAME-tls
APP_HOSTNAME="$AD_APP_NAME.$LOCATION.cloudapp.azure.com"
HOMEPAGE=https://$APP_HOSTNAME
IDENTIFIER_URIS=$HOMEPAGE
REPLY_URLS=https://$APP_HOSTNAME/msal/signin-oidc
CLIENT_ID=""
OBJECT_ID=""
CLIENT_SECRET=""
AZURE_TENANT_ID=""

cat << EOF > manifest.json
[
    {
      "resourceAccess" : [
          {
            "id" : "e1fe6dd8-ba31-4d61-89e7-88639da4683d",
            "type" : "Scope"
          }
      ],
      "resourceAppId" : "00000003-0000-0000-c000-000000000000"
    }
]
EOF

cat manifest.json

# Create the Azure AD SP for our application and save the Client ID to a variable
CLIENT_ID=$(az ad app create --display-name $AD_APP_NAME --homepage $HOMEPAGE --reply-urls $REPLY_URLS --required-resource-accesses @manifest.json -o json | jq -r '.appId')
echo $CLIENT_ID

OBJECT_ID=$(az ad app show --id $CLIENT_ID -o json | jq '.objectId' -r)
echo $OBJECT_ID


az ad app update --id $OBJECT_ID --set "isEnabled=false"

az ad app update --id $OBJECT_ID --set "oauth2Permissions=[]"

# The newly registered app does not have a password.  Use "az ad app credential reset" to add password and save to a variable.
CLIENT_SECRET=$(az ad app credential reset --id $CLIENT_ID -o json | jq '.password' -r)
echo $CLIENT_SECRET

# Get your Azure AD tenant ID and save to variable
AZURE_TENANT_ID=$(az account show -o json | jq '.tenantId' -r)
echo $AZURE_TENANT_ID


kubectl create secret generic aad-secret -n dummy-logger \
  --from-literal=AZURE_TENANT_ID=$AZURE_TENANT_ID \
  --from-literal=CLIENT_ID=$CLIENT_ID \
  --from-literal=CLIENT_SECRET=$CLIENT_SECRET


helm upgrade msal-proxy ./charts/msal-proxy --install -n dummy-logger
kubectl run kuard-pod --image=gcr.io/kuar-demo/kuard-amd64:1 --expose --port=8080 -n dummy-logger

cat << EOF > ./kuard-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: https-$APP_NAMESPACE
  namespace: $APP_NAMESPACE
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt
    nginx.ingress.kubernetes.io/auth-url: "https://\$host/msal/auth"
    nginx.ingress.kubernetes.io/auth-signin: "https://\$host/msal/index?rd=\$escaped_request_uri"
    nginx.ingress.kubernetes.io/auth-response-headers: "x-injected-aio,x-injected-name,x-injected-nameidentifier,x-injected-objectidentifier,x-injected-preferred_username,x-injected-tenantid,x-injected-uti"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
    nginx.ingress.kubernetes.io/configuration-snippet: |
      proxy_ssl_name "default.dummy-logger.cluster.local";
    nginx.ingress.kubernetes.io/proxy-ssl-secret: "kube-system/osm-nginx-client-cert"
    nginx.ingress.kubernetes.io/proxy-ssl-verify: "on"
    nginx.ingress.kubernetes.io/rewrite-target: /\$1
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
      - backend:
          service:
            name: kuard-pod
            port:
              number: 8080
        path: /(.*)
        pathType: ImplementationSpecific
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: msal-proxy
  namespace: $APP_NAMESPACE
spec:
  rules:
  - host: $DNS
    http:
      paths:
      - backend:
          service:
            name: msal-proxy
            port: 
              number: 80
        path: /msal
        pathType: ImplementationSpecific
  tls:
  - hosts:
    - $DNS
    secretName: $SECRET_NAME
EOF
