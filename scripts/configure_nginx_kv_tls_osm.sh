#!/bin/sh

set -e
# https://azure.github.io/secrets-store-csi-driver-provider-azure/configurations/ingress-tls/

KUBE_NAME=$1
KUBE_GROUP=$2
USE_ADDON=$3

KUBE_NAME=dzmtls
KUBE_GROUP=dzmtls

SUBSCRIPTION_ID=$(az account show --query id -o tsv) #subscriptionid
TENANT_ID=$(az account show --query tenantId -o tsv)
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

AKS_KUBELET_CLIENT_ID="$(az identity list -g $KUBE_GROUP --query "[?contains(name, '$KUBE_NAME-kbl-id')].clientId" -o tsv)"
AKS_KUBELET_RESOURCE_ID="$(az identity list -g $KUBE_GROUP --query "[?contains(name, '$KUBE_NAME-kbl-id')].id" -o tsv)"

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


kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/logging/dummy-logger/depl-logger.yaml -n $APP_NAMESPACE
#kubectl apply -f logging/dummy-logger/svc-cluster-logger.yaml -n dummy-logger

kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/logging/dummy-logger/svc-cluster-logger.yaml -n $APP_NAMESPACE

cat <<EOF | kubectl apply -f -
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: ingress-csi-tls
  name: ingress
spec:
  provider: azure
  secretObjects:                                
  - secretName: ingress-tls-csi-cert    #name of the secret that gets created - this is the value we provide to nginx
    type: kubernetes.io/tls
    data: 
    - objectName: $SECRET_NAME
      key: tls.key
    - objectName: $SECRET_NAME
      key: tls.crt
  parameters:
    usePodIdentity: "false"
    useVMManagedIdentity: "true"
    userAssignedIdentityID: "$AKS_KUBELET_CLIENT_ID"
    keyvaultName: "$VAULT_NAME"
    objects:  |
      array:
        - |
          objectName: $SECRET_NAME
          objectType: secret        # object types: secret, key or cert
    tenantId: "$TENANT_ID"                 # the tenant ID of the KeyVault  
EOF

kubectl logs -l  app=secrets-store-csi-driver -n kube-system

sleep 5

# Add the ingress-nginx repository
helm repo add nginx-stable https://helm.nginx.com/stable

# Update the helm repo(s)
helm repo update

  --validating-webhook-certificate=/usr/local/certificates/cert
      --validating-webhook-key=/usr/local/certificates/key

helm upgrade nginx-ingress nginx-stable/nginx-ingress --install \
    --namespace ingress \
    --set controller.replicaCount=1 \
    --set controller.metrics.enabled=true \
    --set controller.service.loadBalancerIP="$IP" \
    --set defaultBackend.enabled=true \
    --set-string controller.service.annotations.'service\.beta\.kubernetes\.io/azure-load-balancer-resource-group'="$KUBE_GROUP" \
    --set-string controller.service.annotations.'service\.beta\.kubernetes\.io/azure-pip-name'="nginxingress" \
    --set controller.service.externalTrafficPolicy=Local --wait --timeout 60s \
    -f - <<EOF
controller:
  extraVolumes:
      - name: secrets-store-inline
        csi:
            driver: secrets-store.csi.k8s.io
            readOnly: true
            volumeAttributes:
              secretProviderClass: "ingress-csi-tls"   #name of the SecretProviderClass we created above
  extraVolumeMounts:
      - name: secrets-store-inline
        mountPath: "/mnt/secrets-store"
        readOnly: true
EOF

#/etc/ssl/certs
# /mnt/secrets-store/mytls-cert-secret

#ln -s /mnt/secrets-store/mytls-cert-secret /etc/ingress-controller/ssl/dummy-logger/ingress-tls-csi-cert
sleep 5

cat <<EOF | kubectl apply -f -
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: ingress-csi-tls-cert
  namespace: $APP_NAMESPACE
spec:
  provider: azure
  secretObjects:                                
  - secretName: ingress-tls-csi-cert    #name of the secret that gets created - this is the value we provide to nginx
    type: kubernetes.io/tls
    data: 
    - objectName: $SECRET_NAME
      key: tls.key
    - objectName: $SECRET_NAME
      key: tls.crt
  parameters:
    usePodIdentity: "false"
    useVMManagedIdentity: "true"
    userAssignedIdentityID: "$AKS_KUBELET_CLIENT_ID"
    keyvaultName: "$VAULT_NAME"
    objects:  |
      array:
        - |
          objectName: $SECRET_NAME
          objectType: cert        # object types: secret, key or cert
          objectVersion: ""         # [OPTIONAL] object versions, default to latest if empty
    tenantId: "$TENANT_ID"                 # the tenant ID of the KeyVault  
EOF

# ssl    on;
# ssl_certificate    /etc/ingress-controller/ssl/dzmtls.westeurope.cloudapp.azure.com.pem;
# ssl_certificate_key    /etc/ingress-controller/ssl/dzmtls.westeurope.cloudapp.azure.com.key;


kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: https-$APP_NAMESPACE
  namespace: $APP_NAMESPACE
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$1
spec:  
  tls:
  - hosts:
    - $DNS
    secretName: ingress-tls-csi-cert
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

kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: https-$APP_NAMESPACE
  namespace: ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:  
  tls:
  - hosts:
    - $DNS
    secretName: ingress-tls-csi-cert
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

curl -v -k --resolve $DNS:443:$IP https://$DNS

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




exit

export CERT_NAME=ingresscert
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -out ingress-tls.crt \
    -keyout ingress-tls.key \
    -subj "/CN=demo.test.com/O=ingress-tls"

openssl pkcs12 -export -in ingress-tls.crt -inkey ingress-tls.key  -out $CERT_NAME.pfx

az keyvault certificate import --vault-name ${VAULT_NAME} -n $SECRET_NAME -f "$CERT_NAME.pfx"

cat <<EOF | kubectl apply -n $NAMESPACE -f -
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

helm install ingress-nginx/ingress-nginx --generate-name \
    --namespace $NAMESPACE \
    --set controller.replicaCount=2 \
    --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux \
    --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux \
    -f - <<EOF
controller:
  extraVolumes:
      - name: secrets-store-inline
        csi:
          driver: secrets-store.csi.k8s.io
          readOnly: true
          volumeAttributes:
            secretProviderClass: "azure-tls"
  extraVolumeMounts:
      - name: secrets-store-inline
        mountPath: "/mnt/secrets-store"
        readOnly: true
EOF

cat <<EOF | kubectl apply -n $NAMESPACE -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-tls
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  tls:
  - hosts:
    - demo.test.com
    secretName: ingress-tls-csi
  rules:
  - host: demo.test.com
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

curl -v -k --resolve demo.test.com:443:20.123.250.240 https://demo.test.com


az k8s-configuration flux create \
   --name cluster-config \
   --cluster-name arc-cicd-cluster \
   --namespace cluster-config \
   --resource-group myResourceGroup \
   -u https://dev.azure.com/<Your organization>/<Your project>/arc-cicd-demo-gitops \
   --https-user <Azure Repos username> \
   --https-key <Azure Repos PAT token> \
   --scope cluster \
   --cluster-type managedClusters \
   --branch master \
   --kustomization name=cluster-config prune=true path=arc-cicd-cluster/manifests