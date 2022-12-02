#!/bin/sh

#
# wget https://raw.githubusercontent.com/denniszielke/container_demos/master/scripts/aks_vnet.sh
# chmod +x ./aks_vnet.sh
# bash ./aks_vnet.sh
#

set -e

DEPLOYMENT_NAME="dzmtlsaks3" # here enter unique deployment name (ideally short and with letters for global uniqueness)

AAD_GROUP_ID="9329d38c-5296-4ecb-afa5-3e74f9abe09f --enable-azure-rbac" # here the AAD group that will be used to lock down AKS authentication
LOCATION="westeurope" # here enter the datacenter location can be eastus or westeurope
KUBE_GROUP=$DEPLOYMENT_NAME # here enter the resources group name of your AKS cluster
KUBE_NAME=$DEPLOYMENT_NAME # here enter the name of your kubernetes resource
NODE_GROUP=$KUBE_GROUP"_"$KUBE_NAME"_nodes_"$LOCATION # name of the node resource group
KUBE_VNET_NAME="$DEPLOYMENT_NAME-vnet"
KUBE_ING_SUBNET_NAME="ing-4-subnet" # here enter the name of your ingress subnet
KUBE_AGENT_SUBNET_NAME="aks-5-subnet" # here enter the name of your AKS subnet
VAULT_NAME=dkv$KUBE_NAME 
SUBSCRIPTION_ID=$(az account show --query id -o tsv) # here enter your subscription id
TENANT_ID=$(az account show --query tenantId -o tsv)
KUBE_VERSION=$(az aks get-versions -l $LOCATION --query 'orchestrators[?default == `true`].orchestratorVersion' -o tsv) # here enter the kubernetes version of your AKS
MY_OWN_OBJECT_ID=$(az ad signed-in-user show --query objectId --output tsv) # this will be your own aad object id

az extension add --name aks-preview
az extension update --name aks-preview

if [ $(az group exists --name $KUBE_GROUP) = false ]; then
    echo "creating resource group $KUBE_GROUP..."
    az group create -n $KUBE_GROUP -l $LOCATION -o none
    echo "resource group $KUBE_GROUP created"
else   
    echo "resource group $KUBE_GROUP already exists"
fi

echo "setting up vnet"

VNET_RESOURCE_ID=$(az network vnet list -g $KUBE_GROUP --query "[?contains(name, '$KUBE_VNET_NAME')].id" -o tsv)
if [ "$VNET_RESOURCE_ID" == "" ]; then
    echo "creating vnet $KUBE_VNET_NAME..."
    az network vnet create  --address-prefixes "10.0.0.0/20"  -g $KUBE_GROUP -n $KUBE_VNET_NAME -o none
    az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_ING_SUBNET_NAME --address-prefix 10.0.4.0/24  -o none
    az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_AGENT_SUBNET_NAME --address-prefix 10.0.5.0/24   -o none
    VNET_RESOURCE_ID=$(az network vnet show -g $KUBE_GROUP -n $KUBE_VNET_NAME --query id -o tsv)
    echo "created $VNET_RESOURCE_ID"
else
    echo "vnet $VNET_RESOURCE_ID already exists"
fi

SECRET_NAME="mySecret"
VAULT_ID=$(az keyvault list -g $KUBE_GROUP --query "[?contains(name, '$VAULT_NAME')].id" -o tsv)
if [ "$VAULT_ID" == "" ]; then
    echo "creating keyvault $VAULT_NAME"
    az keyvault create -g $KUBE_GROUP -n $VAULT_NAME -l $LOCATION -o none
    az keyvault secret set -n $SECRET_NAME --vault-name $VAULT_NAME --value MySuperSecretThatIDontWantToShareWithYou! -o none
    VAULT_ID=$(az keyvault show -g $KUBE_GROUP -n $VAULT_NAME -o tsv --query id)
    echo "created keyvault $VAULT_ID"
else
    echo "keyvault $VAULT_ID already exists"
    VAULT_ID=$(az keyvault show -g $KUBE_GROUP -n $VAULT_NAME -o tsv --query name)
fi

KUBE_AGENT_SUBNET_ID=$(az network vnet subnet show -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_AGENT_SUBNET_NAME --query id -o tsv)

echo "setting up controller identity"
AKS_CONTROLLER_CLIENT_ID="$(az identity list -g $KUBE_GROUP --query "[?contains(name, '$KUBE_NAME-ctl-id')].clientId" -o tsv)"
AKS_CONTROLLER_RESOURCE_ID="$(az identity list -g $KUBE_GROUP --query "[?contains(name, '$KUBE_NAME-clt-id')].id" -o tsv)"
if [ "$AKS_CONTROLLER_RESOURCE_ID" == "" ]; then
    echo "creating controller identity $KUBE_NAME-ctl-id in $KUBE_GROUP"
    az identity create --name $KUBE_NAME-ctl-id --resource-group $KUBE_GROUP -o none
    sleep 5 # wait for replication
    AKS_CONTROLLER_CLIENT_ID="$(az identity show -g $KUBE_GROUP -n $KUBE_NAME-ctl-id --query clientId -o tsv)"
    AKS_CONTROLLER_RESOURCE_ID="$(az identity show -g $KUBE_GROUP -n $KUBE_NAME-ctl-id --query id -o tsv)"
    echo "created controller identity $AKS_CONTROLLER_RESOURCE_ID "
    echo "assigning permissions on network $KUBE_AGENT_SUBNET_ID"
    sleep 25 # wait for replication
    AKS_CONTROLLER_CLIENT_ID="$(az identity show -g $KUBE_GROUP -n $KUBE_NAME-ctl-id --query clientId -o tsv)"
    AKS_CONTROLLER_RESOURCE_ID="$(az identity show -g $KUBE_GROUP -n $KUBE_NAME-ctl-id --query id -o tsv)"
    echo "created controller identity $AKS_CONTROLLER_RESOURCE_ID "
    echo "assigning permissions on network $KUBE_AGENT_SUBNET_ID"
    sleep 5 # wait for replication
    az role assignment create --role "Contributor" --assignee $AKS_CONTROLLER_CLIENT_ID --scope $KUBE_AGENT_SUBNET_ID -o none
else
    echo "controller identity $AKS_CONTROLLER_RESOURCE_ID already exists"
    echo "assigning permissions on network $KUBE_AGENT_SUBNET_ID"
    az role assignment create --role "Contributor" --assignee $AKS_CONTROLLER_CLIENT_ID --scope $KUBE_AGENT_SUBNET_ID -o none
fi

echo "setting up kubelet identity"
AKS_KUBELET_CLIENT_ID="$(az identity list -g $KUBE_GROUP --query "[?contains(name, '$KUBE_NAME-kbl-id')].clientId" -o tsv)"
AKS_KUBELET_RESOURCE_ID="$(az identity list -g $KUBE_GROUP --query "[?contains(name, '$KUBE_NAME-kbl-id')].id" -o tsv)"
if [ "$AKS_KUBELET_CLIENT_ID" == "" ]; then
    echo "creating kubelet identity $KUBE_NAME-kbl-id in $KUBE_GROUP"
    az identity create --name $KUBE_NAME-kbl-id --resource-group $KUBE_GROUP -o none
    sleep 5 # wait for replication
    AKS_KUBELET_CLIENT_ID="$(az identity show -g $KUBE_GROUP -n $KUBE_NAME-kbl-id --query clientId -o tsv)"
    AKS_KUBELET_RESOURCE_ID="$(az identity show -g $KUBE_GROUP -n $KUBE_NAME-kbl-id --query id -o tsv)"
    echo "created kubelet identity $AKS_KUBELET_RESOURCE_ID "
    sleep 25 # wait for replication
    AKS_KUBELET_CLIENT_ID="$(az identity show -g $KUBE_GROUP -n $KUBE_NAME-kbl-id --query clientId -o tsv)"
    AKS_KUBELET_RESOURCE_ID="$(az identity show -g $KUBE_GROUP -n $KUBE_NAME-kbl-id --query id -o tsv)"
    echo "created kubelet identity $AKS_KUBELET_RESOURCE_ID "
    echo "assigning permissions on keyvault $VAULT_ID"
    az keyvault set-policy -n $VAULT_NAME --object-id $AKS_KUBELET_CLIENT_ID --key-permissions get --certificate-permissions get -o none
else
    echo "kubelet identity $AKS_KUBELET_RESOURCE_ID already exists"
    echo "assigning permissions on keyvault $VAULT_ID"
    az keyvault set-policy -n $VAULT_NAME --object-id $AKS_KUBELET_CLIENT_ID --key-permissions get --certificate-permissions get -o none
fi

echo "setting up aks"
AKS_ID=$(az aks list -g $KUBE_GROUP --query "[?contains(name, '$KUBE_NAME')].id" -o tsv)

if [ "$AKS_ID" == "" ]; then
    echo "creating AKS $KUBE_NAME in $KUBE_GROUP"
    echo "using host subnet $KUBE_AGENT_SUBNET_ID"
    az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME$AKS_POSTFIX --ssh-key-value ~/.ssh/id_rsa.pub  --node-count 3 --node-vm-size "Standard_B2s" --min-count 3 --max-count 5 --enable-cluster-autoscaler --auto-upgrade-channel patch  --node-resource-group $NODE_GROUP --load-balancer-sku standard --enable-vmss  --network-plugin azure --vnet-subnet-id $KUBE_AGENT_SUBNET_ID --docker-bridge-address 172.17.0.1/16 --dns-service-ip 10.2.0.10 --service-cidr 10.2.0.0/24 --kubernetes-version $KUBE_VERSION --assign-identity $AKS_CONTROLLER_RESOURCE_ID --assign-kubelet-identity $AKS_KUBELET_RESOURCE_ID --node-osdisk-size 300 --enable-managed-identity --enable-aad --aad-admin-group-object-ids $AAD_GROUP_ID --aad-tenant-id $TENANT_ID --network-policy calico --enable-addons "azure-keyvault-secrets-provider,open-service-mesh"  -o none
    az aks update --resource-group $KUBE_GROUP --name $KUBE_NAME --auto-upgrade-channel node-image
    # az aks enable-addons --resource-group="$KUBE_GROUP" --name="$KUBE_NAME" --addons="azure-keyvault-secrets-provider"
    az aks update --resource-group="$KUBE_GROUP" --name="$KUBE_NAME" --enable-secret-rotation
    # az aks enable-addons --resource-group="$KUBE_GROUP" --name="$KUBE_NAME" --addons="open-service-mesh"
    AKS_ID=$(az aks show -g $KUBE_GROUP -n $KUBE_NAME --query id -o tsv)
    echo "created AKS $AKS_ID"
else
    echo "AKS $AKS_ID already exists"
fi

AKS_OIDC_ISSUER="$(az aks show -n $KUBE_NAME -g $KUBE_GROUP --query "oidcIssuerProfile.issuerUrl" -o tsv)"

echo "setting up azure monitor"

WORKSPACE_RESOURCE_ID=$(az monitor log-analytics workspace list --resource-group $KUBE_GROUP --query "[?contains(name, '$KUBE_NAME')].id" -o tsv)
if [ "$WORKSPACE_RESOURCE_ID" == "" ]; then
    echo "creating workspace $KUBE_NAME in $KUBE_GROUP"
    az monitor log-analytics workspace create --resource-group $KUBE_GROUP --workspace-name $KUBE_NAME --location $LOCATION -o none
    WORKSPACE_RESOURCE_ID=$(az monitor log-analytics workspace show --resource-group $KUBE_GROUP --workspace-name $KUBE_NAME -o json | jq '.id' -r)
    az aks enable-addons --resource-group $KUBE_GROUP --name $KUBE_NAME --addons monitoring --workspace-resource-id $WORKSPACE_RESOURCE_ID
    OMS_CLIENT_ID=$(az aks show -g $KUBE_GROUP -n $KUBE_NAME --query addonProfiles.omsagent.identity.clientId -o tsv)
    az role assignment create --assignee $OMS_CLIENT_ID --scope $AKS_ID --role "Monitoring Metrics Publisher"
fi

IP_ID=$(az network public-ip list -g $NODE_GROUP --query "[?contains(name, 'nginxingress')].id" -o tsv)
if [ "$IP_ID" == "" ]; then
    echo "creating ingress ip nginxingress"
    az network public-ip create -g $NODE_GROUP -n nginxingress --sku STANDARD --dns-name $KUBE_NAME -o none
    IP_ID=$(az network public-ip show -g $NODE_GROUP -n nginxingress -o tsv)
    IP=$(az network public-ip show -g $NODE_GROUP -n nginxingress -o tsv --query ipAddress)
    DNS=$(az network public-ip show -g $NODE_GROUP -n nginxingress -o tsv --query dnsSettings.fqdn)
    echo "created ip $IP_ID with $IP on $DNS"
else
    IP=$(az network public-ip show -g $NODE_GROUP -n nginxingress -o tsv --query ipAddress)
    DNS=$(az network public-ip show -g $NODE_GROUP -n nginxingress -o tsv --query dnsSettings.fqdn)
    echo "AKS $AKS_ID already exists with $IP on $DNS"
fi


az aks get-credentials --resource-group=$KUBE_GROUP --name=$KUBE_NAME --admin --overwrite-existing 

echo "created this AKS cluster:"

az aks show  --resource-group=$KUBE_GROUP --name=$KUBE_NAME


kubectl create namespace ingress

# Add the ingress-nginx repository
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

# Update the helm repo(s)
helm repo update



#az aks disable-addons --addons "open-service-mesh" --name $KUBE_NAME --resource-group $KUBE_GROUP 

osm install

kubectl create ns dummy-logger

osm namespace add dummy-logger

kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/logging/dummy-logger/depl-logger.yaml -n dummy-logger
kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/logging/dummy-logger/svc-cluster-logger.yaml -n dummy-logger

# Use Helm to deploy an NGINX ingress controller in the ingress-basic namespace
helm upgrade nginx-ingress ingress-nginx/ingress-nginx --install \
    --namespace ingress \
    --set controller.replicaCount=2 \
    --set controller.metrics.enabled=true \
    --set controller.service.loadBalancerIP="$IP" \
    --set defaultBackend.enabled=true \
    --set controller.service.externalTrafficPolicy=Local

osm_namespace=osm-system # replace <osm-namespace> with the namespace where OSM is installed
osm_mesh_name=osm # replace <osm-mesh-name> with the mesh name (use `osm mesh list` command)

nginx_ingress_namespace=ingress # replace <nginx-namespace> with the namespace where Nginx is installed
nginx_ingress_service=nginx-ingress-ingress-nginx-controller # replace <nginx-ingress-controller-service> with the name of the nginx ingress controller service
nginx_ingress_host="$(kubectl -n "$nginx_ingress_namespace" get service "$nginx_ingress_service" -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
nginx_ingress_port="$(kubectl -n "$nginx_ingress_namespace" get service "$nginx_ingress_service" -o jsonpath='{.spec.ports[?(@.name=="http")].port}')"

kubectl label ns "$nginx_ingress_namespace" openservicemesh.io/monitored-by="$osm_mesh_name"

kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: http-dummy-logger
  namespace: dummy-logger
spec:
  ingressClassName: nginx
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: dummy-logger
            port:
              number: 80
---
kind: IngressBackend
apiVersion: policy.openservicemesh.io/v1alpha1
metadata:
  name: http-dummy-logger
  namespace: dummy-logger
spec:
  backends:
  - name: dummy-logger
    port:
      number: 80
      protocol: http
  sources:
  - kind: Service
    namespace: "$nginx_ingress_namespace"
    name: "$nginx_ingress_service"
EOF



kubectl edit meshconfig osm-mesh-config -n osm-system

kubectl patch meshconfig osm-mesh-config -n osm-system -p '{"spec":{"certificate:":{"ingressGateway": {"secret": {"name": "osm-nginx-client-cert","namespace": "osm-system"},"subjectAltNames": ["nginx-ingress-ingress-nginx-controller.ingress.cluster.local"],"validityDuration": "24h"}}}}'  --type=merge
kubectl get meshconfig osm-mesh-config -n osm-system

certificate:
    ingressGateway:
      secret:
        name: osm-nginx-client-cert
        namespace: osm-system 
      subjectAltNames:
      - nginx-ingress-ingress-nginx-controller.ingress.cluster.local
      validityDuration: 24h

kubectl label namespace ingress-basic cert-manager.io/disable-validation=true
helm repo add jetstack https://charts.jetstack.io

helm repo update

CERT_MANAGER_REGISTRY=quay.io
CERT_MANAGER_TAG=v1.3.1
CERT_MANAGER_IMAGE_CONTROLLER=jetstack/cert-manager-controller
CERT_MANAGER_IMAGE_WEBHOOK=jetstack/cert-manager-webhook
CERT_MANAGER_IMAGE_CAINJECTOR=jetstack/cert-manager-cainjector

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
  --set cainjector.image.tag=$CERT_MANAGER_TAG

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

kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: https-dummy-logger
  namespace: dummy-logger
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt
spec:  
  tls:
  - hosts:
    - $DNS
    secretName: dummy-cert-secret
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

curl -sI http://"$DNS"/get

kubectl get secret dummy-cert-secret -n dummy-logger -o json | jq '.data | map_values(@base64d)'

openssl pkcs12 -export -in ingress-tls.crt -inkey ingress-tls.key  -out $CERT_NAME.pfx
# skip Password prompt

az keyvault certificate import --vault-name ${KEYVAULT_NAME} -n $CERT_NAME -f $CERT_NAME.pfx

cat <<EOF | kubectl apply -f -
apiVersion: secrets-store.csi.x-k8s.io/v1alpha1
kind: SecretProviderClass
metadata:
  name: ingress-tls
  namespace: ingress
spec:
  provider: azure
  parameters:
    usePodIdentity: "false"
    useVMManagedIdentity: "true"
    userAssignedIdentityID: "$AKS_KUBELET_CLIENT_ID"
    keyvaultName: "$VAULT_NAME"
    cloudName: ""                   # [OPTIONAL for Azure] if not provided, azure environment will default to AzurePublicCloud
    objects:  |
      array:
        - |
          objectName: mySecret
          objectType: secret        # object types: secret, key or cert
          objectVersion: ""         # [OPTIONAL] object versions, default to latest if empty
    tenantId: "$TENANT_ID"                 # the tenant ID of the KeyVault  
EOF


cat <<EOF | kubectl apply -f -
kind: Pod
apiVersion: v1
metadata:
  name: busybox-secrets-store-inline-user-msi
  namespace: ingress
spec:
  containers:
    - name: busybox
      image: k8s.gcr.io/e2e-test-images/busybox:1.29
      command:
        - "/bin/sleep"
        - "10000"
      volumeMounts:
      - name: secrets-store01-inline
        mountPath: "/mnt/secrets-store"
        readOnly: true
  volumes:
    - name: secrets-store01-inline
      csi:
        driver: secrets-store.csi.k8s.io
        readOnly: true
        volumeAttributes:
          secretProviderClass: "ingress-tls"
EOF


AD_APP_NAME="$DEPLOYMENT_NAME-msal-proxy"
APP_HOSTNAME="$DNS"
HOMEPAGE=https://$APP_HOSTNAME
IDENTIFIER_URIS=$HOMEPAGE
REPLY_URLS=https://$APP_HOSTNAME/msal/signin-oidc

CLIENT_ID=""
OBJECT_ID=""

CLIENT_ID=$(az ad app create --display-name $AD_APP_NAME --homepage $HOMEPAGE --reply-urls $REPLY_URLS --required-resource-accesses @manifest.json -o json | jq -r '.appId')
echo $CLIENT_ID

OBJECT_ID=$(az ad app show --id $CLIENT_ID -o json | jq '.objectId' -r)
echo $OBJECT_ID

az ad app update --id $OBJECT_ID --set "oauth2Permissions=[]"

# The newly registered app does not have a password.  Use "az ad app credential reset" to add password and save to a variable.
CLIENT_SECRET=$(az ad app credential reset --id $CLIENT_ID -o json | jq '.password' -r)
echo $CLIENT_SECRET

# Get your Azure AD tenant ID and save to variable
AZURE_TENANT_ID=$(az account show -o json | jq '.tenantId' -r)
echo $AZURE_TENANT_ID

curl 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fmanagement.azure.com%2F&client_id=ff3756e7-f35e-4128-a352-4b5623c94d43' -H Metadata:true -s


export SERVICE_ACCOUNT_NAMESPACE="default"
export SERVICE_ACCOUNT_NAME="workload-identity-sa"
AKS_OIDC_ISSUER="$(az aks show -n $KUBE_NAME -g $KUBE_GROUP --query "oidcIssuerProfile.issuerUrl" -o tsv)"
SECRET_NAME="mySecret"
# user assigned identity name
export UAID="$KUBE_NAME-fic"
# federated identity name
export FICID="$KUBE_NAME-fic" 
VAULT_NAME=dzkv$KUBE_NAME

az identity create --name $KUBE_NAME-fic --resource-group $KUBE_GROUP -o none

export USER_ASSIGNED_CLIENT_ID="$(az identity show --resource-group "${KUBE_GROUP}" --name "$KUBE_NAME-fic" --query 'clientId' -o tsv)"

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  annotations:
    azure.workload.identity/client-id: ${USER_ASSIGNED_CLIENT_ID}
  labels:
    azure.workload.identity/use: "true"
  name: ${SERVICE_ACCOUNT_NAME}
  namespace: ${SERVICE_ACCOUNT_NAMESPACE}
EOF

az identity federated-credential create --name ${FICID} --identity-name ${FICID} --resource-group $KUBE_GROUP --issuer ${AKS_OIDC_ISSUER} --subject system:serviceaccount:${SERVICE_ACCOUNT_NAMESPACE}:${SERVICE_ACCOUNT_NAME}

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: quick-start
  namespace: ${SERVICE_ACCOUNT_NAMESPACE}
spec:
  serviceAccountName: ${SERVICE_ACCOUNT_NAME}
  containers:
    - image: ghcr.io/azure/azure-workload-identity/msal-go
      name: oidc
      env:
      - name: KEYVAULT_NAME
        value: ${VAULT_NAME}
      - name: SECRET_NAME
        value: ${SECRET_NAME}
  nodeSelector:
    kubernetes.io/os: linux
EOF

kubectl exec -it centos-token -- /bin/bash  

cat /var/run/secrets/azure/tokens/azure-identity-token

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: centos-token
  namespace: ${SERVICE_ACCOUNT_NAMESPACE}
spec:
  serviceAccountName: ${SERVICE_ACCOUNT_NAME}
  containers:
  - name: centoss
    image: centos
    ports:
    - containerPort: 80
    command:
    - sleep
    - "3600"
EOF

cat <<EOF | kubectl apply -f -
apiVersion: secrets-store.csi.x-k8s.io/v1alpha1
kind: SecretProviderClass
metadata:
  name: azure-kvname-user-msi
  namespace: default
spec:
  provider: azure
  parameters:
    usePodIdentity: "false"
    clientID: "$USER_ASSIGNED_CLIENT_ID"
    keyvaultName: "$VAULT_NAME"
    cloudName: ""                   # [OPTIONAL for Azure] if not provided, azure environment will default to AzurePublicCloud
    objects:  |
      array:
        - |
          objectName: mySecret
          objectType: secret        # object types: secret, key or cert
          objectVersion: ""         # [OPTIONAL] object versions, default to latest if empty
    tenantId: "$TENANT_ID"                 # the tenant ID of the KeyVault  
EOF

cat <<EOF | kubectl apply -f -
kind: Pod
apiVersion: v1
metadata:
  name: busybox-secrets-store-inline-wi
spec:
  containers:
    - name: busybox
      image: k8s.gcr.io/e2e-test-images/busybox:1.29
      command:
        - "/bin/sleep"
        - "10000"
      volumeMounts:
      - name: secrets-store01-inline
        mountPath: "/mnt/secrets-store"
        readOnly: true
  volumes:
    - name: secrets-store01-inline
      csi:
        driver: secrets-store.csi.k8s.io
        readOnly: true
        volumeAttributes:
          secretProviderClass: "azure-kvname-user-msi"
EOF