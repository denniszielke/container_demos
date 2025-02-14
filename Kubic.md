# Kubic

```
DEPLOYMENT_NAME="dzkubic2" # here enter unique deployment name (ideally short and with letters for global uniqueness)
USE_PRIVATE_API="false" # use to deploy private master endpoint
USE_POD_SUBNET="false"
USE_OVERLAY="false"
USE_CILIUM="" #="--enable-cilium-dataplane"
VNET_PREFIX="0"

AAD_GROUP_ID="0644b510-7b35-41aa-a9c6-4bfc3f644c58 --enable-azure-rbac" # here the AAD group that will be used to lock down AKS authentication
LOCATION="eastus2euap" # "northcentralus" "northeurope" #"southcentralus" #"eastus2euap" #"westeurope" # here enter the datacenter location can be eastus or westeurope
KUBE_GROUP=$DEPLOYMENT_NAME # here enter the resources group name of your AKS cluster
KUBE_NAME=$DEPLOYMENT_NAME # here enter the name of your kubernetes resource
NODE_GROUP=$KUBE_GROUP"_"$KUBE_NAME"_nodes_"$LOCATION # name of the node resource group
KUBE_VNET_NAME="$DEPLOYMENT_NAME-vnet"
KUBE_FW_SUBNET_NAME="AzureFirewallSubnet" # this you cannot change
BASTION_SUBNET_NAME="AzureBastionSubnet" # this you cannot change
APPGW_SUBNET_NAME="gw-1-subnet"
KUBE_ING_SUBNET_NAME="ing-4-subnet" # here enter the name of your ingress subnet
KUBE_API_SUBNET_NAME="api-0-subnet"
KUBE_AGENT_SUBNET_NAME="aks-5-subnet" # here enter the name of your AKS subnet
POD_AGENT_SUBNET_NAME="pod-8-subnet"
ACI_AGENT_SUBNET_NAME="aci-7-subnet"
VAULT_NAME=dzkv$KUBE_NAME 
SUBSCRIPTION_ID=$(az account show --query id -o tsv) # here enter your subscription id
TENANT_ID=$(az account show --query tenantId -o tsv)
export KUBECONFIG=$HOME/.kube/$KUBE_NAME

KUBE_ING_SUBNET_NAME="ing-4-subnet"
KUBE_VNET_NAME="$KUBE_NAME-vnet"
TRAFFIC_CONTROLLER_NAME='dz-tf-ctl'
FRONTEND_NAME='frontend'
RESOURCE_GROUP=$KUBE_GROUP
AKS_NAME="$KUBE_NAME"
ALB="atc1" #alb resource name
IDENTITY_RESOURCE_NAME='azure-alb-identity'
NODE_GROUP="dzobs4all_dzobs4all_nodes_"

tcSubnetId=$(az network vnet subnet show --resource-group $KUBE_GROUP --vnet-name $KUBE_VNET_NAME --name $KUBE_ING_SUBNET_NAME --query id -o tsv)
albSubnetId=$tcSubnetId

az identity create --resource-group $RESOURCE_GROUP --name $IDENTITY_RESOURCE_NAME
principalId="$(az identity show -g $RESOURCE_GROUP -n $IDENTITY_RESOURCE_NAME --query principalId -o tsv)"

az role assignment create --assignee-object-id $principalId --assignee-principal-type ServicePrincipal --scope $NODE_GROUP --role "acdd72a7-3385-48ef-bd42-f606fba81ae7"
az role assignment create --assignee-object-id $principalId --resource-group $NODE_GROUP --role "Contributor"
az role assignment create --assignee-object-id $principalId --resource-group $NODE_GROUP --role "fbc52c3f28ad4303a8928a056630b8f1"
az role assignment create --assignee-object-id $principalId --scope $tcSubnetId --role "Network Contributor"

az identity federated-credential create --name "azure-alb-identity" \
    --identity-name "$IDENTITY_RESOURCE_NAME" \
    --resource-group $RESOURCE_GROUP \
    --issuer "$AKS_OIDC_ISSUER" \
    --subject "system:serviceaccount:azure-alb-system:alb-controller-sa"

ALB_WL_ID=$(az identity show -g $RESOURCE_GROUP -n azure-alb-identity --query clientId -o tsv)

helm upgrade --install  alb-controller oci://mcr.microsoft.com/application-lb/charts/alb-controller \
    --namespace azure-alb-system --create-namespace \
    --version 0.5.024542 \
    --set albController.podIdentity.clientID=$ALB_WL_ID

helm upgrade  \
  --install alb-controller oci://mcr.microsoft.com/application-lb/charts/alb-controller --namespace azure-alb-system --create-namespace \
  --version 0.4.023971 \
  --set albController.podIdentity.clientID=$ALB_WL_ID

az deployment group create \
	--resource-group $KUBE_GROUP \
	--name 'sample-traffic-controller-deployment' \
	--template-uri 'https://trafficcontrollerdocs.blob.core.windows.net/templates/traffic-controller.template.json' \
	--parameters "trafficControllerName=$TRAFFIC_CONTROLLER_NAME" \
	--parameters "frontendName=$FRONTEND_NAME" \
	--parameters "subnetId=$tcSubnetId" \
	--parameters "mcResourceGroup=$NODE_GROUP"

# Verify the Traffic Controller
az resource show --ids $(az resource list --resource-type 'Microsoft.ServiceNetworking/trafficControllers' --resource-group $KUBE_GROUP --query '[].id' -o tsv)

# Verify the Traffic Controller Association
az resource show --ids $(az resource list --resource-type 'Microsoft.ServiceNetworking/trafficControllers/associations' --resource-group $KUBE_GROUP --query '[].id' -o tsv)

# Verify the Traffic Controller Frontend
az resource show --ids $(az resource list --resource-type 'Microsoft.ServiceNetworking/trafficControllers/frontends' --resource-group $KUBE_GROUP --query '[].id' -o tsv)

AKS_OIDC_ISSUER="$(az aks show -n "$KUBE_NAME" -g "$KUBE_GROUP" --query "oidcIssuerProfile.issuerUrl" -o tsv)"
az identity federated-credential create --name "azure-application-lb-identity" \
    --identity-name "azure-application-lb-identity" \
	--resource-group $KUBE_GROUP \
	--issuer "$AKS_OIDC_ISSUER" \
	--subject "system:serviceaccount:azure-application-lb-system:gateway-controller-sa"

ATF_CLIENT_ID=$(az identity show -g $KUBE_GROUP -n azure-application-lb-identity --query clientId -o tsv)

helm upgrade \
	--install gateway-controller oci://mcr.microsoft.com/application-lb/charts/gateway-controller \
	--create-namespace --namespace azure-application-lb-system \
	--version '0.1.022981' \
	--set gatewayController.podIdentity.clientID=$ATF_CLIENT_ID

kubectl get pods -n azure-application-lb-system

kubectl get gatewayclass azure-application-lb -o yaml


kubectl apply -f - <<EOF
apiVersion: networking.azure.io/v1alpha1
kind: ApplicationLbParam
metadata:
  name: default
spec:
  ipAddress:
  subnetPrefix:
  loadBalancerId: $(az resource show --resource-type 'Microsoft.ServiceNetworking/trafficControllers' -g $KUBE_GROUP -n $TRAFFIC_CONTROLLER_NAME --query id -o tsv)
EOF

publicDNS=$(az resource show --namespace Microsoft.ServiceNetworking --resource-type frontends --resource-group $KUBE_GROUP --name $FRONTEND_NAME --parent "trafficControllers/$TRAFFIC_CONTROLLER_NAME" --query 'properties.fqdn' -o tsv)

{
  "properties": {
    "fqdn": "2949680a16f5bf1d17e6d49952b878bb.fz51.trafficcontroller.azure.com",
    "provisioningState": "Succeeded"
  },
  "id": "/subscriptions/892cd868-0dde-415d-9178-fa99dd1d04a5/resourcegroups/dzkubic2/providers/Microsoft.ServiceNetworking/trafficControllers/dz-tf-ctl/frontends/frontend",
  "name": "frontend",
  "type": "Microsoft.ServiceNetworking/TrafficControllers/Frontends",
  "etag": "2e087dcb-40ab-4cdb-aae6-7afa3719ece3",
  "location": "eastus2euap"
}

ip=$(az network public-ip show --id $publicIPAddressId --query "ipAddress" -o tsv)

kubectl apply -f https://trafficcontrollerdocs.blob.core.windows.net/examples/http-scenario/deployment.yaml

kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: gateway-01
  namespace: test-infra
spec:
  gatewayClassName: azure-application-lb
  listeners:
  - name: http
    port: 80
    protocol: HTTP
    allowedRoutes:
      namespaces:
        from: Same
  addresses:
  - type: NamedAddress
    value: 2949680a16f5bf1d17e6d49952b878bb.fz51.trafficcontroller.azure.com
EOF

kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: query-param-matching
  namespace: test-infra
spec:
  parentRefs:
  - name: gateway-01
  rules:
  - matches:
    - queryParams:
      - name: animal
        value: whale
    backendRefs:
    - name: backend-v1
      port: 8080
  - matches:
    - queryParams:
      - name: animal
        value: dolphin
    backendRefs:
    - name: backend-v2
      port: 8080
EOF


https://github.com/kubernetes-sigs/gateway-api/blob/main/site-src/geps/gep-1016.md
https://gateway-api.sigs.k8s.io/v1alpha2/references/spec/#gateway.networking.k8s.io/v1alpha2.GRPCBackendRef
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: GRPCRoute
metadata:
  name: grpc
  namespace: default
spec:
  parentRefs:
  - name: gateway-01
  rules:
  - matches:
      method:
        service: helloworld.Greeter
        method:  SayHello
    backendRefs:
    - name: backend-v1
      port: 8080
EOF

curl "$ip?animal=dolphin"

# this curl command will return a response from backend-v1 only
curl "$ip?animal=whale"



kubectl apply -f - <<EOF
apiVersion: networking.azure.io/v1alpha1
kind: ApplicationLbParam
metadata:
  name: dummy
spec:
  ipAddress:
  subnetPrefix:
  loadBalancerId: $(az resource show --resource-type 'Microsoft.ServiceNetworking/trafficControllers' -g $KUBE_GROUP -n $TRAFFIC_CONTROLLER_NAME --query id -o tsv)
EOF

publicIPAddressId=$(az resource show --namespace Microsoft.ServiceNetworking --resource-type frontends --resource-group $KUBE_GROUP --name $FRONTEND_NAME --parent "trafficControllers/$TRAFFIC_CONTROLLER_NAME" --query 'properties.publicIPAddress.id' -o tsv)
ip=$(az network public-ip show --id $publicIPAddressId --query "ipAddress" -o tsv)

kubectl apply -f https://trafficcontrollerdocs.blob.core.windows.net/examples/http-scenario/deployment.yaml

kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: gateway-02
spec:
  gatewayClassName: azure-application-lb
  listeners:
  - name: http
    port: 80
    protocol: HTTP
    allowedRoutes:
      namespaces:
        from: Same
EOF


kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: query-param-matching
  namespace: test-infra
spec:
  parentRefs:
  - name: gateway-01
  rules:
  - matches:
    - queryParams:
      - name: animal
        value: whale
    backendRefs:
    - name: backend-v1
      port: 8080
  - matches:
    - queryParams:
      - name: animal
        value: dolphin
    backendRefs:
    - name: backend-v2
      port: 8080
EOF

kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: dummy-matching
  namespace: test-infra
spec:
  parentRefs:
  - name: gateway-01
  hostnames:
  - "dztraffic.eastus2.cloudapp.azure.com"
  rules:
  - backendRefs:
    - name: dummy-logger
      port: 80
EOF

```


cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1alpha2
kind: Gateway
metadata:
  name: bingAdds-gateway
  namespace: bingAdds
  annotation:
    kubic/frontend-name: "bingAdds"   #Will be created if doesnot exist. If not specified a default frontend will be created
    kubic/publicip-id: "/a/b/c"       # Optional. Needed only when customer needs to provide a precreated IP
spec:
  gatewayClassName: azure-kubic
  listeners:
  - name: http
    protocol: HTTP
    port: 80
---
apiVersion: gateway.networking.k8s.io/v1alpha2
kind: HTTPRoute
metadata:
  name: bingAdds-route
  namespace: bingAdds
spec:
  parentRefs:
  - name: bingAdds-gateway
  hostnames:
  - "bingAdds.com"
  rules:
  - backendRefs:
    - name: bingAdds-svc
      port: 80
---
EOF

cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: gateway-01
  namespace: $ALB-infra
  annotations:
    alb.networking.azure.io/alb-namespace: $ALB-infra
    alb.networking.azure.io/alb-name: $ALB
spec:
  gatewayClassName: azure-alb-external
  listeners:
  - name: http
    port: 80
    protocol: HTTP
    allowedRoutes:
      namespaces:
        from: Selector
        selector:
          matchLabels:
            shared-gateway-access: 'true'
EOF 

apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: gateway-01
  namespace: $ALB-infra
  annotations:
    alb.networking.azure.io/alb-namespace: $ALB-infra
    alb.networking.azure.io/alb-name: $ALB
spec:
  gatewayClassName: azure-alb-external
  listeners:
  - name: http
    port: 80
    protocol: HTTP
    allowedRoutes:
      namespaces:
        from: Selector
        selector:
          matchLabels:
            shared-gateway-access: "true"


cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: bingSearch-gateway
  namespace: bingSearch
  annotation:
    kubic/frontend-name: "bingSearch" # Will be created if doesnot exist. If not specified a default frontend will be created
    kubic/publicip-id: "/a/b/c"       # Optional. Needed only when customer needs to provide a precreated IP
spec:
  gatewayClassName: azure-kubic
  listeners:
  - name: http
    protocol: HTTP
    port: 80
---
apiVersion: gateway.networking.k8s.io/v1alpha2
kind: HTTPRoute
metadata:
  name: example-route
spec:
  parentRefs:
  - name: bingSearch-gateway
  hostnames:
  - "example.com"
  rules:
  - backendRefs:
    - name: example-svc
      port: 80
EOF

az network kubic create --name prod-app-store --location "eastus"

{
    "name": "kubic1",
    "type": "Microsoft.Networkfunctions/kubic",
    "location": "",
    "tags": {},
    "properties": {
        "frontends": [
            {
                "name": "publicIp1",
                "publicIPAddress": {
                    "id": "/subscriptions/xxxx/resourceGroups/app-store-rg/providers/Microsoft.Network/publicIPAddresses/global-ip"
                }
            }
        ]
    }
}

## Traffic split
```
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: gateway-01
  namespace: test-infra
spec:
  gatewayClassName: azure-application-lb
  listeners:
  - name: http
    port: 80
    protocol: HTTP
    allowedRoutes:
      namespaces:
        from: Same
  addresses:
  - type: NamedAddress
    value: 2949680a16f5bf1d17e6d49952b878bb.fz51.trafficcontroller.azure.com
EOF

kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: traffic-split-route
  namespace: test-infra
spec:
  parentRefs:
  - name: gateway-01
  rules:
  - backendRefs:
    - name: backend-v1
      port: 8080
      weight: 50
    - name: backend-v2
      port: 8080
      weight: 50
EOF

```

## GRPC

```
cat <<EOF | kubectl apply -f -
---
apiVersion: v1
kind: Service
metadata:
  name: grpc-server
  labels:
    app: grpc-server
spec:
  ports:
  - name: grpc
    port: 9001
    targetPort: 9001
  selector:
    app: grpc-server
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grpc-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grpc-server
  template:
    metadata:
      labels:
        app: grpc-server
    spec:
      containers:
      - image: denniszielke/grpc-server
        name: grpc-server
        ports:
        - containerPort: 9001
EOF
```

## Letsencrypt

```
AKS_NAME="dzatc4" #cluster name
RESOURCE_GROUP="dzatc4" #cluster resource group

KUBE_NAME="dznetgw"    
KUBE_GROUP="$KUBE_NAME"
AKS_NAME="$KUBE_NAME"
RESOURCE_GROUP="$KUBE_NAME"
ALB="atc1" #alb resource name
IDENTITY_RESOURCE_NAME='azure-alb-identity' # alb controller identity

DNS_ZONE_ID=$(az network dns zone list -g blobs -o tsv --query "[].id")
DNS_ZONE=$(az network dns zone list -g blobs -o tsv --query "[].name")

SUB_ID=$(az account show --query id -o tsv) #subscriptionid             
ALB_SUBNET_ID="/subscriptions/$SUB_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/virtualNetworks/$RESOURCE_GROUP-vnet/subnets/ing-4-subnet" #subnet resource id of your ALB subnet
NODE_GROUP=$(az aks show --resource-group $RESOURCE_GROUP --name $AKS_NAME --query "nodeResourceGroup" -o tsv) #infrastructure resource group of your cluster
NODE_GROUP_ID="/subscriptions/$SUB_ID/resourceGroups/$NODE_GROUP"
KUBE_GROUP_ID="/subscriptions/$SUB_ID/resourceGroups/$RESOURCE_GROUP"
AKS_OIDC_ISSUER="$(az aks show -n "$AKS_NAME" -g "$RESOURCE_GROUP" --query "oidcIssuerProfile.issuerUrl" -o tsv)" # oidc issuer url of your cluster

az identity create --resource-group $RESOURCE_GROUP --name $IDENTITY_RESOURCE_NAME
ALB_PRINCIPAL_ID="$(az identity show -g $RESOURCE_GROUP -n $IDENTITY_RESOURCE_NAME --query principalId -o tsv)"

echo "Waiting 60 seconds to allow for replication of the identity..."
sleep 60

az network alb create -g $RESOURCE_GROUP -n $ALB

az network alb frontend create -g $RESOURCE_GROUP -n $ALB-frontend --alb-name $ALB

az role assignment create --assignee-object-id $ALB_PRINCIPAL_ID --scope $KUBE_GROUP_ID --role "AppGw for Containers Configuration Manager"
az role assignment create --assignee-object-id $ALB_PRINCIPAL_ID --scope $ALB_SUBNET_ID --role "Network Contributor"

az network alb association create -g $RESOURCE_GROUP -n $ALB-link --alb-name $ALB --subnet $ALB_SUBNET_ID

az identity federated-credential create --name $IDENTITY_RESOURCE_NAME \
     --identity-name "azure-alb-identity" \
     --resource-group $RESOURCE_GROUP \
     --issuer "$AKS_OIDC_ISSUER" \
     --subject "system:serviceaccount:azure-alb-system:alb-controller-sa"

ALB_WL_ID=$(az identity show -g $RESOURCE_GROUP -n azure-alb-identity --query clientId -o tsv)

helm upgrade  \
  --install alb-controller oci://mcr.microsoft.com/application-lb/charts/alb-controller \
  --namespace azure-alb-system --create-namespace \
  --version 0.6.3 \
  --set albController.namespace=azure-alb-system \
  --set albController.podIdentity.clientID=$ALB_WL_ID

ALB_RESOURCE_ID=$(az network alb show --resource-group $RESOURCE_GROUP --name $ALB --query id -o tsv)

kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: $ALB-infra
EOF

kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: gateway-01
  namespace: $ALB-infra
  annotations:
    alb.networking.azure.io/alb-id: $ALB_RESOURCE_ID
spec:
  gatewayClassName: azure-alb-external
  listeners:
  - name: http
    port: 80
    protocol: HTTP
    allowedRoutes:
      namespaces:
        from: Selector
        selector:
          matchLabels:
            shared-gateway-access: "true"
  addresses:
  - type: alb.networking.azure.io/alb-frontend
    value: $ALB-frontend
EOF

https://cert-manager.io/docs/configuration/acme/http01/

kubectl apply -f "https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/standard-install.yaml"

helm upgrade --install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace \
  --set "extraArgs={--feature-gates=ExperimentalGatewayAPISupport=true}" --version v1.14.2 --set installCRDs=true

kubectl label namespace $ALB-infra shared-gateway-access=true 

kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: letsencrypt
  namespace: $ALB-infra
spec:
  acme:
    email: mail@$DNS_ZONE
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: my-issuer-account-key
    solvers:
      - http01:
          gatewayHTTPRoute:
            parentRefs:
              - name: gateway-01
                namespace: $ALB-infra
                kind: Gateway
EOF


kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: example-tls
  namespace: $ALB-infra
spec:
  issuerRef:
    name: letsencrypt
  secretName: my-cert
  dnsNames:
  - events.$DNS_ZONE
EOF


kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: gateway-01
  namespace: $ALB-infra
  annotations:
    alb.networking.azure.io/alb-id: $ALB_RESOURCE_ID
spec:
  gatewayClassName: azure-alb-external
  listeners:
  - name: http
    port: 80
    protocol: HTTP
    allowedRoutes:
      namespaces:
        from: Selector
        selector:
          matchLabels:
            shared-gateway-access: "true"
  - name: https
    port: 443
    protocol: HTTPS
    hostname: "events.$DNS_ZONE"
    tls:
      mode: Terminate
      certificateRefs:
      - kind: Secret
        name: my-cert
    allowedRoutes:
      namespaces:
        from: Selector
        selector:
          matchLabels:
            shared-gateway-access: "true"
  addresses:
  - type: alb.networking.azure.io/alb-frontend
    value: $ALB-frontend
EOF

helm repo add phoenix 'https://raw.githubusercontent.com/denniszielke/phoenix/master/'
helm repo update
helm search repo phoenix 

AZURE_CONTAINER_REGISTRY_NAME=phoenix
KUBERNETES_NAMESPACE=calculator
BUILD_BUILDNUMBER=latest
AZURE_CONTAINER_REGISTRY_URL=denniszielke

kubectl create namespace $KUBERNETES_NAMESPACE
kubectl label namespace $KUBERNETES_NAMESPACE shared-gateway-access=true 

helm upgrade calculator $AZURE_CONTAINER_REGISTRY_NAME/multicalculator --namespace $KUBERNETES_NAMESPACE --install --create-namespace --set replicaCount=5 --set image.frontendTag=$BUILD_BUILDNUMBER --set image.backendTag=$BUILD_BUILDNUMBER --set image.repository=$AZURE_CONTAINER_REGISTRY_URL --set gateway.enabled=true --set gateway.name=gateway-01 --set gateway.namespace=$ALB-infra --set slot=blue

curl http://$fqdn/ping
```