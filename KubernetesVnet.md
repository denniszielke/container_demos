# Create container cluster in a VNET (AKs)
https://docs.microsoft.com/en-us/cli/azure/acs?view=azure-cli-latest#az_acs_create
https://docs.microsoft.com/en-us/azure/aks/networking-overview

0. Variables
```
SUBSCRIPTION_ID=""
KUBE_GROUP="kubenets"
KUBE_NAME="dkubes"
LOCATION="westeurope"
KUBE_VNET_NAME="knets"
KUBE_GW_SUBNET_NAME="gw-1-subnet"
KUBE_ACI_SUBNET_NAME="aci-2-subnet"
KUBE_FW_SUBNET_NAME="AzureFirewallSubnet"
KUBE_ING_SUBNET_NAME="ing-4-subnet"
KUBE_AGENT_SUBNET_NAME="aks-5-subnet"
KUBE_VERSION="1.12.7"
SERVICE_PRINCIPAL_ID=
SERVICE_PRINCIPAL_SECRET=
AAD_APP_NAME=""
AAD_APP_ID=
AAD_APP_SECRET=
AAD_CLIENT_NAME=
AAD_CLIENT_ID=
TENANT_ID=
```

Select subscription
```
az account set --subscription $SUBSCRIPTION_ID
```

1. Create the resource group
```
az group create -n $KUBE_GROUP -l $LOCATION
```

2. Create VNETs
```
az network vnet create -g $KUBE_GROUP -n $KUBE_VNET_NAME 
```

Get available service endpoints
```
az network vnet list-endpoint-services -l $LOCATION
```

Assign permissions on vnet
```
az role assignment create --role "Virtual Machine Contributor" --assignee $SERVICE_PRINCIPAL_ID -g $KUBE_GROUP
az role assignment create --role "Contributor" --assignee $SERVICE_PRINCIPAL_ID -g $KUBE_GROUP
```

Create dns zone
```
az network dns zone create -g $KUBE_GROUP  -n runningcode.local  --zone-type Private --registration-vnets $KUBE_VNET_NAME

KUBE_GW_SUBNET_NAME="gw-1-subnet"
KUBE_ACI_SUBNET_NAME="aci-2-subnet"
KUBE_FW_SUBNET_NAME="AzureFirewallSubnet"
KUBE_ING_SUBNET_NAME="ing-4-subnet"
KUBE_AGENT_SUBNET_NAME="aks-5-subnet"
```

3. Create Subnets
Register azure firewall https://docs.microsoft.com/en-us/azure/firewall/public-preview

```
az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_GW_SUBNET_NAME --address-prefix 10.0.1.0/24
az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_ACI_SUBNET_NAME --address-prefix 10.0.2.0/24 --service-endpoints Microsoft.Sql Microsoft.AzureCosmosDB Microsoft.KeyVault
az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_FW_SUBNET_NAME --address-prefix 10.0.3.0/24
az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_ING_SUBNET_NAME --address-prefix 10.0.4.0/24
az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_AGENT_SUBNET_NAME --address-prefix 10.0.5.0/24 --service-endpoints Microsoft.Sql Microsoft.AzureCosmosDB Microsoft.KeyVault Microsoft.Storage
```

4. Create the aks cluster

get vm sizes
```
az vm list-sizes -l $LOCATION
```

create cluster without rbac
```

KUBE_AGENT_SUBNET_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$KUBE_GROUP/providers/Microsoft.Network/virtualNetworks/$KUBE_VNET_NAME/subnets/$KUBE_AGENT_SUBNET_NAME"

az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --node-count 1 --ssh-key-value ~/.ssh/id_rsa.pub  --enable-vmss --network-plugin azure --vnet-subnet-id $KUBE_AGENT_SUBNET_ID --docker-bridge-address 172.17.0.1/16 --dns-service-ip 10.2.0.10 --service-cidr 10.2.0.0/24 --client-secret $SERVICE_PRINCIPAL_SECRET --service-principal $SERVICE_PRINCIPAL_ID --kubernetes-version $KUBE_VERSION --network-policy calico --enable-rbac --enable-addons monitoring
```

for additional rbac
```
KUBE_AGENT_SUBNET_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$KUBE_GROUP/providers/Microsoft.Network/virtualNetworks/$KUBE_VNET_NAME/subnets/$KUBE_AGENT_SUBNET_NAME"

az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --node-count 2  --ssh-key-value ~/.ssh/id_rsa.pub --network-plugin azure --vnet-subnet-id $KUBE_AGENT_SUBNET_ID --docker-bridge-address 172.17.0.1/16 --dns-service-ip 10.2.0.10 --service-cidr 10.2.0.0/24 --client-secret $SERVICE_PRINCIPAL_SECRET --service-principal $SERVICE_PRINCIPAL_ID --kubernetes-version $KUBE_VERSION --enable-rbac --aad-server-app-id $AAD_APP_ID --aad-server-app-secret $AAD_APP_SECRET --aad-client-app-id $AAD_CLIENT_ID --aad-tenant-id $TENANT_ID --node-vm-size "Standard_B2s"

az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --node-count 2  --ssh-key-value ~/.ssh/id_rsa.pub --network-plugin azure --vnet-subnet-id $KUBE_AGENT_SUBNET_ID --docker-bridge-address 172.17.0.1/16 --dns-service-ip 10.2.0.10 --service-cidr 10.2.0.0/24 --client-secret $SERVICE_PRINCIPAL_SECRET --service-principal $SERVICE_PRINCIPAL_ID --kubernetes-version $KUBE_VERSION --enable-rbac --node-vm-size "Standard_D2s_v3"

```

with kubenet
```
az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --node-count 2  --ssh-key-value ~/.ssh/id_rsa.pub --network-plugin kubenet --vnet-subnet-id $KUBE_AGENT_SUBNET_ID --docker-bridge-address 172.17.0.1/16 --dns-service-ip 10.2.0.10 --service-cidr 10.2.0.0/24 --client-secret $SERVICE_PRINCIPAL_SECRET --service-principal $SERVICE_PRINCIPAL_ID --kubernetes-version $KUBE_VERSION --enable-rbac --node-vm-size "Standard_D2s_v3"

```

--node-vm-size "Standard_B2s"
--node-vm-size "Standard_D2s_v3"

create cluster via arm
```

sed -e "s/KUBE_NAME/$KUBE_NAME/ ; s/LOCATION/$LOCATION/ ; s/SERVICE_PRINCIPAL_ID/$SERVICE_PRINCIPAL_ID/ ; s/SERVICE_PRINCIPAL_SECRET/$SERVICE_PRINCIPAL_SECRET/ ; s/KUBE_VERSION/$KUBE_VERSION/ ; s/SUBSCRIPTION_ID/$SUBSCRIPTION_ID/ ; s/KUBE_GROUP/$KUBE_GROUP/ ; s/GROUP_ID/$GROUP_ID/" acsengvnet-ha.json > acsengvnet_out.json

az group deployment create \
    --name dz-vnet-acs \
    --resource-group $KUBE_GROUP \
    --template-file "arm/azurecni_template.json" \
    --parameters "arm/azurecni_parameters.json"
```

5. Export the kubectrl credentials files
```
az aks get-credentials --resource-group=$KUBE_GROUP --name=$KUBE_NAME
```

or RBAC
https://github.com/denniszielke/container_demos/blob/master/KubernetesRBAC.md

```
az aks get-credentials --resource-group $KUBE_GROUP --name $KUBE_NAME --admin
```


create addition dns record
```
az network dns zone list --resource-group $KUBE_GROUP

az network dns record-set list -g $KUBE_GROUP -z runningcode.local

az network dns zone show -g $KUBE_GROUP -n contoso.com -o json


az network dns record-set a add-record \
  -g $KUBE_GROUP \
  -z runningcode.local \
  -n dummy \
  -a 10.0.4.24

curl 10.0.4.24
curl nginx.runningcode.local
````

create internal load balancer for nginx

kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/services/nginx-internal.yaml
kubectl run nginx --image=nginx --port=80

```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: internal-nginx
  annotations:
    service.beta.kubernetes.io/azure-load-balancer-internal: "true"
spec:
  type: LoadBalancer
  ports:
  - port: 80
  selector:
    run: nginx
EOF
```

```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: centos1
spec:
  containers:
  - name: centoss
    image: centos
    ports:
    - containerPort: 80
    command:
    - sleep
    - "3600"
EOF
```