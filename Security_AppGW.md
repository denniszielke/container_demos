# AppGW Ingress Controller


## AGIC Config variables

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
KUBE_NAME="dzgwenv1"
AGIC_IDENTITY_NAME=$KUBE_NAME"-id"
APPGW_NAME=$KUBE_NAME"-gw"
KUBE_GROUP="infra"
LOCATION="westeurope"
NODE_GROUP=$KUBE_GROUP"_"$KUBE_NAME"_nodes_"$LOCATION
KUBE_VNET_NAME=$KUBE_NAME"-vnet"
KUBE_GW_SUBNET_NAME="gw-1-subnet"
KUBE_ACI_SUBNET_NAME="aci-2-subnet"
KUBE_FW_SUBNET_NAME="AzureFirewallSubnet"
KUBE_ING_SUBNET_NAME="ing-4-subnet"
KUBE_AGENT_SUBNET_NAME="aks-5-subnet"
KUBE_AGENT2_SUBNET_NAME="aks-6-subnet"
KUBE_VERSION="1.16.10"
SERVICE_PRINCIPAL_ID=
SERVICE_PRINCIPAL_SECRET=

### deploy cluster
```
SERVICE_PRINCIPAL_ID=$(az ad sp create-for-rbac --skip-assignment --name $KUBE_NAME -o json | jq -r '.appId')
echo $SERVICE_PRINCIPAL_ID

SERVICE_PRINCIPAL_SECRET=$(az ad app credential reset --id $SERVICE_PRINCIPAL_ID -o json | jq '.password' -r)
echo $SERVICE_PRINCIPAL_SECRET
```

### deploy vnet
```
az group create -n $KUBE_GROUP -l $LOCATION
az network vnet create -g $KUBE_GROUP -n $KUBE_VNET_NAME 
az role assignment create --role "Contributor" --assignee $SERVICE_PRINCIPAL_ID -g $KUBE_GROUP
az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_GW_SUBNET_NAME --address-prefix 10.0.1.0/24
az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_ACI_SUBNET_NAME --address-prefix 10.0.2.0/24 --service-endpoints Microsoft.Sql Microsoft.AzureCosmosDB Microsoft.KeyVault
az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_FW_SUBNET_NAME --address-prefix 10.0.3.0/24
az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_ING_SUBNET_NAME --address-prefix 10.0.4.0/24
az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_AGENT_SUBNET_NAME --address-prefix 10.0.5.0/24 --service-endpoints Microsoft.Sql Microsoft.AzureCosmosDB Microsoft.KeyVault Microsoft.Storage
az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_AGENT2_SUBNET_NAME --address-prefix 10.0.6.0/24 --service-endpoints Microsoft.Sql Microsoft.AzureCosmosDB Microsoft.KeyVault Microsoft.Storage
```

### deploy cluster
```
KUBE_AGENT_SUBNET_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$KUBE_GROUP/providers/Microsoft.Network/virtualNetworks/$KUBE_VNET_NAME/subnets/$KUBE_AGENT_SUBNET_NAME"
az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --node-count 1 --ssh-key-value ~/.ssh/id_rsa.pub  --enable-vmss --network-plugin kubenet --vnet-subnet-id $KUBE_AGENT_SUBNET_ID --docker-bridge-address 172.17.0.1/16 --dns-service-ip 10.2.0.10 --service-cidr 10.2.0.0/24 --pod-cidr 10.244.0.0/16  --client-secret $SERVICE_PRINCIPAL_SECRET --service-principal $SERVICE_PRINCIPAL_ID --kubernetes-version $KUBE_VERSION --network-policy calico --enable-rbac --load-balancer-sku standard --enable-addons monitoring

AKS_FQDN=$(az aks show -g ${KUBE_GROUP} -n ${KUBE_NAME} --query "fqdn" -o tsv)
```

### deploy gateway
```

az network public-ip create \
  --resource-group $KUBE_GROUP \
  --name $APPGW_NAME-pip \
  --allocation-method Static \
  --sku Standard

az network application-gateway create --name $APPGW_NAME --resource-group $KUBE_GROUP --location $LOCATION --capacity 2 --sku Standard_v2  --vnet-name $KUBE_NAME-vnet --subnet gw-1-subnet --http-settings-cookie-based-affinity Disabled --frontend-port 80 --http-settings-port 80 --http-settings-protocol Http --public-ip-address $APPGW_NAME-pip


APPGW_NAME=$(az network application-gateway list --resource-group=$KUBE_GROUP -o json | jq -r ".[0].name")
APPGW_RESOURCE_ID=$(az network application-gateway list --resource-group=$KUBE_GROUP -o json | jq -r ".[0].id")
APPGW_SUBNET_ID=$(az network application-gateway list --resource-group=$KUBE_GROUP -o json | jq -r ".[0].gatewayIpConfigurations[0].subnet.id")
```

### copy routetable
```

NODE_GROUP=$(az aks show -g ${KUBE_GROUP} -n ${KUBE_NAME} --query "nodeResourceGroup" -o tsv)
AKS_AGENT_SUBNET_ID=$(az aks show -g ${KUBE_GROUP} -n ${KUBE_NAME} --query "agentPoolProfiles[0].vnetSubnetId" -o tsv)
AKS_ROUTE_TABLE_ID=$(az network route-table list -g ${NODE_GROUP} --query "[].id | [0]" -o tsv)
AKS_ROUTE_TABLE_NAME=$(az network route-table list -g ${NODE_GROUP} --query "[].name | [0]" -o tsv)
AKS_NODE_NSG=$(az network nsg list -g ${NODE_GROUP} --query "[].id | [0]" -o tsv)

az network route-table create -g $KUBE_GROUP --name $APPGW_NAME-rt

APPGW_ROUTE_TABLE_ID=$(az network route-table show -g ${KUBE_GROUP} -n $APPGW_NAME-rt --query "id" -o tsv)

az network nsg create --name $APPGW_NAME-rt --resource-group $KUBE_GROUP --location $LOCATION

az network nsg rule create --name appgwrule --nsg-name $APPGW_NAME-rt --resource-group $KUBE_GROUP --priority 110 \
    --source-address-prefixes '*' --source-port-ranges '*' \
    --destination-address-prefixes '*' --destination-port-ranges '*' --access Allow --direction Inbound \
    --protocol "*" --description "Required allow rule for AppGW."
APPGW_NSG=$(az network nsg list -g ${KUBE_GROUP} --query "[].id | [0]" -o tsv)

az network vnet subnet update --resource-group $KUBE_GROUP --route-table $APPGW_ROUTE_TABLE_ID --network-security-group $APPGW_NSG --ids $APPGW_SUBNET_ID

AKS_ROUTES=$(az network route-table route list --resource-group $NODE_GROUP --route-table-name $AKS_ROUTE_TABLE_NAME)

az network route-table route list --resource-group $NODE_GROUP --route-table-name $AKS_ROUTE_TABLE_NAME --query "[][name,addressPrefix,nextHopIpAddress]" -o tsv |
while read -r name addressPrefix nextHopIpAddress; do
   echo "checking route $name"
   echo "creating new hop $name selecting $addressPrefix configuring $nextHopIpAddress as next hop"
   az network route-table route create --resource-group $KUBE_GROUP --name $name --route-table-name $APPGW_NAME-rt --address-prefix $addressPrefix --next-hop-type VirtualAppliance --next-hop-ip-address $nextHopIpAddress --subscription $SUBSCRIPTION_ID
done


az network route-table route list --resource-group $KUBE_GROUP --route-table-name $APPGW_NAME-rt 
```

### deploy aad pod identity
https://github.com/Azure/aad-pod-identity/tree/master/charts/aad-pod-identity#configuration
https://github.com/Azure/aad-pod-identity#deploy-the-azure-aad-identity-infra

```

helm repo add aad-pod-identity https://raw.githubusercontent.com/Azure/aad-pod-identity/master/charts
helm install aad-pod-identity aad-pod-identity/aad-pod-identity


kubectl apply -f https://raw.githubusercontent.com/Azure/aad-pod-identity/master/deploy/infra/deployment-rbac.yaml
# For managed identity clusters, deploy the MIC exception by running -
kubectl apply -f https://raw.githubusercontent.com/Azure/aad-pod-identity/v1.5.5/deploy/infra/deployment-rbac.yaml

kubectl apply -f https://raw.githubusercontent.com/Azure/aad-pod-identity/master/deploy/infra/mic-exception.yaml


az identity create -g $NODE_GROUP -n $AGIC_IDENTITY_NAME --subscription $SUBSCRIPTION_ID


AGIC_MSI_CLIENT_ID=$(az identity show -n $AGIC_IDENTITY_NAME -g $NODE_GROUP -o json | jq -r ".clientId")
echo "$AGIC_MSI_CLIENT_ID"
AGIC_MSI_RESOURCE_ID=$(az identity show -n $AGIC_IDENTITY_NAME -g $NODE_GROUP -o json | jq -r ".id")
echo $AGIC_MSI_RESOURCE_ID

export IDENTITY_ASSIGNMENT_ID="$(az role assignment create --role Reader --assignee $AGIC_MSI_CLIENT_ID --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$NODE_GROUP --query id -otsv)"
export IDENTITY_ASSIGNMENT_ID="$(az role assignment create --role Reader --assignee $AGIC_MSI_CLIENT_ID --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$KUBE_GROUP --query id -otsv)"
export IDENTITY_ASSIGNMENT_ID="$(az role assignment create --role Contributor --assignee $AGIC_MSI_CLIENT_ID --scope $APPGW_RESOURCE_ID --query id -otsv)"

```

deploy azure identity
```
cat <<EOF | kubectl apply -f -
apiVersion: "aadpodidentity.k8s.io/v1"
kind: AzureIdentity
metadata:
  name: $AGIC_IDENTITY_NAME
spec:
  type: 0
  resourceID: $AGIC_MSI_RESOURCE_ID
  clientID: $AGIC_MSI_CLIENT_ID
EOF

kubectl get AzureIdentity $AGIC_IDENTITY_NAME -o yaml
```

deploy binding
```
cat <<EOF | kubectl apply -f -
apiVersion: "aadpodidentity.k8s.io/v1"
kind: AzureIdentityBinding
metadata:
  name: $AGIC_IDENTITY_NAME-binding
spec:
  azureIdentity: $AGIC_IDENTITY_NAME
  selector: $AGIC_IDENTITY_NAME
EOF

kubectl get AzureIdentityBinding $AGIC_IDENTITY_NAME-binding -o yaml

```

### deploy agic


```
helm repo add application-gateway-kubernetes-ingress https://appgwingress.blob.core.windows.net/ingress-azure-helm-package/


helm repo update

helm search repo application-gateway-kubernetes-ingress

kubectl create namespace appgw

helm install ingress-azure application-gateway-kubernetes-ingress/ingress-azure \
     --namespace appgw \
     --debug \
     --set appgw.name=$APPGW_NAME \
     --set appgw.resourceGroup=$KUBE_GROUP \
     --set appgw.subscriptionId=$SUBSCRIPTION_ID \
     --set appgw.usePrivateIP=false \
     --set appgw.shared=false \
     --set armAuth.type=aadPodIdentity \
     --set armAuth.identityClientID=$AGIC_MSI_CLIENT_ID \
     --set armAuth.identityResourceID=$AGIC_MSI_RESOURCE_ID \
     --set rbac.enabled=true \
     --set verbosityLevel=3 \
     --set kubernetes.watchNamespace=default \
     --set aksClusterConfiguration.apiServerAddress=$AKS_FQDN


```

from source

```

git clone https://github.com/Azure/application-gateway-kubernetes-ingress.git

cd application-gateway-kubernetes-ingress/helm

helm upgrade ingress-azure ./ingress-azure --install \
     --namespace appgw \
     --debug \
     --set appgw.name=$APPGW_NAME \
     --set appgw.resourceGroup=$KUBE_GROUP \
     --set appgw.subscriptionId=$SUBSCRIPTION_ID \
     --set appgw.usePrivateIP=false \
     --set appgw.shared=false \
     --set armAuth.type=aadPodIdentity \
     --set armAuth.identityClientID=$AGIC_MSI_CLIENT_ID \
     --set armAuth.identityResourceID=$AGIC_MSI_RESOURCE_ID \
     --set rbac.enabled=true \
     --set verbosityLevel=3 \
     --set kubernetes.watchNamespace=default \
     --set aksClusterConfiguration.apiServerAddress=$AKS_FQDN

helm upgrade ingress-azure ./ingress-azure --install \
     --namespace appgw \
     --debug \
     --set appgw.name=$APPGW_NAME \
     --set appgw.resourceGroup=$KUBE_GROUP \
     --set appgw.subscriptionId=$SUBSCRIPTION_ID \
     --set appgw.usePrivateIP=false \
     --set appgw.shared=false \
     --set armAuth.type=aadPodIdentity \
     --set armAuth.identityClientID=$AGIC_MSI_CLIENT_ID \
     --set armAuth.identityResourceID=$AGIC_MSI_RESOURCE_ID \
     --set rbac.enabled=true \
     --set verbosityLevel=3 \
     --set kubernetes.watchNamespace=default \
     --set aksClusterConfiguration.apiServerAddress=$AKS_FQDN

helm template ingress-azure ./ingress-azure \
     --namespace appgw \
     --debug \
     --set appgw.name=$APPGW_NAME \
     --set appgw.resourceGroup=$KUBE_GROUP \
     --set appgw.subscriptionId=$SUBSCRIPTION_ID \
     --set appgw.usePrivateIP=false \
     --set appgw.shared=false \
     --set armAuth.type=aadPodIdentity \
     --set armAuth.identityClientID=$AGIC_MSI_CLIENT_ID \
     --set armAuth.identityResourceID=$AGIC_MSI_RESOURCE_ID \
     --set rbac.enabled=true \
     --set verbosityLevel=3 \
     --set kubernetes.watchNamespace=default \
     --set aksClusterConfiguration.apiServerAddress=$AKS_FQDN
```

### test

```
kubectl logs -n kube-system -l app=ingress-azure

kubectl apply -f https://raw.githubusercontent.com/kubernetes/examples/master/guestbook/all-in-one/guestbook-all-in-one.yaml

cat <<EOF | kubectl apply -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: guestbook
  annotations:
    kubernetes.io/ingress.class: azure/application-gateway
spec:
  rules:
  - http:
      paths:
      - backend:
          serviceName: frontend
          servicePort: 80
EOF

kubectl delete ingress guestbook

kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/logging/dummy-logger/depl-logger.yaml
kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/logging/dummy-logger/svc-logger.yaml
kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/logging/dummy-logger/echo-server.yaml

cat <<EOF | kubectl apply -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: dummy-logger
  annotations:
    kubernetes.io/ingress.class: azure/application-gateway
spec:
  rules:
  - http:
      paths:
      - backend:
          serviceName: dummy-logger
          servicePort: 80
EOF

kubectl delete ingress dummy-logger

cat <<EOF | kubectl apply -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: dummy-logger-private
  annotations:
    kubernetes.io/ingress.class: azure/application-gateway
    appgw.ingress.kubernetes.io/use-private-ip: "true"
spec:
  rules:
  - http:
      paths:
      - backend:
          serviceName: dummy-logger
          servicePort: 80
EOF

cat <<EOF | kubectl apply -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: dummy-logger-private
  annotations:
    appgw.ingress.kubernetes.io/backend-path-prefix: /dummy
    kubernetes.io/ingress.class: azure/application-gateway
    appgw.ingress.kubernetes.io/use-private-ip: "true"
    appgw.ingress.kubernetes.io/backend-hostname: "dummy.example.com"
spec:
  rules:
  - host: dummy.example.com
    http:
      paths:
      - path: /dummy/
        backend:
          serviceName: dummy-logger
          servicePort: 80
EOF

cat <<EOF | kubectl apply -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: echo-service
  annotations:
    appgw.ingress.kubernetes.io/backend-path-prefix: /echo
    kubernetes.io/ingress.class: azure/application-gateway
    appgw.ingress.kubernetes.io/use-private-ip: "true"
    appgw.ingress.kubernetes.io/backend-hostname: "src.example.com"
spec:
  rules:
  - host: src.example.com
    http:
      paths:
      - path: /echo/
        backend:
          serviceName: echo-service
          servicePort: 80
EOF

cat <<EOF | kubectl apply -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: echo-service
  annotations:
    kubernetes.io/ingress.class: azure/application-gateway
    appgw.ingress.kubernetes.io/use-private-ip: "true"
spec:
  rules:
  - host: src.example.com
    http:
      paths:
      - path: /echo/
        backend:
          serviceName: echo-service
          servicePort: 80
  - host: dummy.example.com
    http:
      paths:
      - path: /dummy/
        backend:
          serviceName: dummy-logger
          servicePort: 80
EOF

curl http://src.example.com --resolve src.example.com:80:10.0.4.100
curl http://dummy.example.com --resolve dummy.example.com:80:10.0.4.100

kubectl delete ingress dummy-logger-private

cat <<EOF | kubectl apply -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: guestbook
  annotations:
    kubernetes.io/ingress.class: azure/application-gateway
spec:
  rules:
  - http:
      paths:
      - backend:
          serviceName: frontend
          servicePort: 80
EOF

```