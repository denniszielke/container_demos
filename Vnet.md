# Create container cluster in a VNET (AKs)
https://docs.microsoft.com/en-us/cli/azure/acs?view=azure-cli-latest#az_acs_create
https://docs.microsoft.com/en-us/azure/aks/networking-overview

0. Variables
```
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)
KUBE_NAME="podsub2"
KUBE_GROUP="kub_ter_a_m_$KUBE_NAME"
LOCATION="westcentralus"
NODE_GROUP=$KUBE_GROUP"_"$KUBE_NAME"_nodes_"$LOCATION
KUBE_VNET_NAME=$KUBE_NAME"-vnet"
KUBE_GW_SUBNET_NAME="gw-1-subnet"
KUBE_ACI_SUBNET_NAME="aci-2-subnet"
KUBE_FW_SUBNET_NAME="AzureFirewallSubnet"
KUBE_ING_SUBNET_NAME="ing-4-subnet"
KUBE_AGENT_SUBNET_NAME="aks-5-subnet"
KUBE_AGENT2_SUBNET_NAME="aks-6-subnet"
KUBE_AGENT3_SUBNET_NAME="aks-7-subnet"
KUBE_VERSION="$(az aks get-versions -l $LOCATION --query 'orchestrators[?default == `true`].orchestratorVersion' -o tsv)"
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
az network vnet create -g $KUBE_GROUP -n $KUBE_VNET_NAME --address-prefixes 192.168.0.0/20 172.16.0.0/16 10.0.0.0/16
```

Get available service endpoints
```
az network vnet list-endpoint-services -l $LOCATION
```

create ip prefix
```
az network public-ip prefix create --length 31 --location $LOCATION --name aksprefix --resource-group $KUBE_GROUP
```

Assign permissions on vnet
```
az identity create --name $KUBE_NAME -g $KUBE_GROUP

SERVICE_PRINCIPAL_ID=$(az ad sp create-for-rbac --skip-assignment --name $SP_NAME -o json | jq -r '.appId')
echo $SERVICE_PRINCIPAL_ID

SERVICE_PRINCIPAL_SECRET=$(az ad app credential reset --id $SERVICE_PRINCIPAL_ID -o json | jq '.password' -r)
echo $SERVICE_PRINCIPAL_SECRET
az role assignment create --role "Virtual Machine Contributor" --assignee $SERVICE_PRINCIPAL_ID -g $KUBE_GROUP
az role assignment create --role "Contributor" --assignee $SERVICE_PRINCIPAL_ID -g $KUBE_GROUP
```

Create dns zone
```
az network dns zone create -g $KUBE_GROUP  -n runningcode.local  --zone-type Private --registration-vnets $KUBE_VNET_NAME
```

3. Create Subnets
Register azure firewall https://docs.microsoft.com/en-us/azure/firewall/public-preview

```
az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_GW_SUBNET_NAME --address-prefix 10.0.1.0/24
az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_ACI_SUBNET_NAME --address-prefix 10.0.2.0/24 --service-endpoints Microsoft.Sql Microsoft.AzureCosmosDB Microsoft.KeyVault
az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_FW_SUBNET_NAME --address-prefix 10.0.3.0/24
az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_ING_SUBNET_NAME --address-prefix 10.0.4.0/24
az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_AGENT_SUBNET_NAME --address-prefix 10.0.5.0/24 --service-endpoints Microsoft.Sql Microsoft.AzureCosmosDB Microsoft.KeyVault Microsoft.Storage
az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_AGENT2_SUBNET_NAME --address-prefix 10.0.6.0/24 --service-endpoints Microsoft.Sql Microsoft.AzureCosmosDB Microsoft.KeyVault Microsoft.Storage

az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_AGENT2_SUBNET_NAME --address-prefix 192.168.0.0/24 --service-endpoints Microsoft.Sql Microsoft.AzureCosmosDB Microsoft.KeyVault Microsoft.Storage

az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_AGENT3_SUBNET_NAME --address-prefix 172.16.0.0/24 --service-endpoints Microsoft.Sql Microsoft.AzureCosmosDB Microsoft.KeyVault Microsoft.Storage
```

4. Create the aks cluster

get vm sizes
```
az vm list-sizes -l $LOCATION
```

create cluster without rbac
```

KUBE_AGENT_SUBNET_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$KUBE_GROUP/providers/Microsoft.Network/virtualNetworks/$KUBE_VNET_NAME/subnets/$KUBE_AGENT_SUBNET_NAME"

KUBE_AGENT2_SUBNET_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$KUBE_GROUP/providers/Microsoft.Network/virtualNetworks/$KUBE_VNET_NAME/subnets/$KUBE_AGENT2_SUBNET_NAME"

KUBE_AGENT3_SUBNET_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$KUBE_GROUP/providers/Microsoft.Network/virtualNetworks/$KUBE_VNET_NAME/subnets/$KUBE_AGENT3_SUBNET_NAME"

CONTROLLER_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$KUBE_GROUP/providers/Microsoft.ManagedIdentity/userAssignedIdentities/$KUBE_NAME"

MSI_CLIENT_ID=$(az identity show -n $KUBE_NAME -g $KUBE_GROUP --query clientId -o tsv)

az role assignment create --role "Contributor" --assignee $MSI_CLIENT_ID -g $KUBE_GROUP # will be done by aks-engine

az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --node-count 2 --ssh-key-value ~/.ssh/id_rsa.pub  --enable-vmss --network-plugin azure --vnet-subnet-id $KUBE_AGENT_SUBNET_ID --docker-bridge-address 172.17.0.1/16 --dns-service-ip 10.2.0.10 --service-cidr 10.2.0.0/24 --client-secret $SERVICE_PRINCIPAL_SECRET --service-principal $SERVICE_PRINCIPAL_ID --kubernetes-version $KUBE_VERSION --network-policy calico --enable-rbac --enable-addons monitoring

az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --node-count 2 --ssh-key-value ~/.ssh/id_rsa.pub --enable-vmss --network-plugin azure --vnet-subnet-id $KUBE_AGENT_SUBNET_ID --pod-subnet-id $KUBE_AGENT3_SUBNET_ID --docker-bridge-address 172.17.0.1/16 --dns-service-ip 10.2.0.10 --service-cidr 10.2.0.0/24 --client-secret $SERVICE_PRINCIPAL_SECRET --service-principal $SERVICE_PRINCIPAL_ID --kubernetes-version $KUBE_VERSION --network-policy calico --enable-rbac --aks-custom-headers EnableSwiftNetworking=true --enable-addons monitoring

az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --node-count 2 --ssh-key-value ~/.ssh/id_rsa.pub  --enable-vmss --network-plugin azure --vnet-subnet-id $KUBE_AGENT_SUBNET_ID --docker-bridge-address 172.17.0.1/16 --dns-service-ip 10.2.0.10 --service-cidr 10.2.0.0/24  --network-policy calico --enable-rbac --enable-addons monitoring --enable-managed-identity --aks-custom-headers CustomizedUbuntu=aks-ubuntu-1804,ContainerRuntime=containerd 

az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --node-count 2 --ssh-key-value ~/.ssh/id_rsa.pub  --enable-vmss --network-plugin kubenet --vnet-subnet-id $KUBE_AGENT_SUBNET_ID --docker-bridge-address 172.17.0.1/16 --dns-service-ip 10.2.0.10 --service-cidr 10.2.0.0/24  --network-policy calico --enable-rbac --enable-addons monitoring --enable-managed-identity --assign-identity $CONTROLLER_ID --outbound-type userDefinedRouting

az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --node-count 2 --ssh-key-value ~/.ssh/id_rsa.pub  --enable-vmss --network-plugin kubenet --vnet-subnet-id $KUBE_AGENT_SUBNET_ID --docker-bridge-address 172.17.0.1/16 --dns-service-ip 10.2.0.10 --service-cidr 10.2.0.0/24 --enable-rbac --kubernetes-version $KUBE_VERSION --enable-addons monitoring --enable-managed-identity --assign-identity $CONTROLLER_ID 
```

for additional rbac
```
az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --node-count 2  --ssh-key-value ~/.ssh/id_rsa.pub --network-plugin azure --vnet-subnet-id $KUBE_AGENT_SUBNET_ID --docker-bridge-address 172.17.0.1/16 --dns-service-ip 10.2.0.10 --service-cidr 10.2.0.0/24 --client-secret $SERVICE_PRINCIPAL_SECRET --service-principal $SERVICE_PRINCIPAL_ID --kubernetes-version $KUBE_VERSION --enable-rbac --aad-server-app-id $AAD_APP_ID --aad-server-app-secret $AAD_APP_SECRET --aad-client-app-id $AAD_CLIENT_ID --aad-tenant-id $TENANT_ID --node-vm-size "Standard_B2s"

az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --node-count 2  --ssh-key-value ~/.ssh/id_rsa.pub --network-plugin azure --vnet-subnet-id $KUBE_AGENT_SUBNET_ID --docker-bridge-address 172.17.0.1/16 --dns-service-ip 10.2.0.10 --service-cidr 10.2.0.0/24 --client-secret $SERVICE_PRINCIPAL_SECRET --service-principal $SERVICE_PRINCIPAL_ID --kubernetes-version $KUBE_VERSION --enable-rbac --node-vm-size "Standard_D2s_v3"

```

with kubenet
```
az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --node-count 2  --ssh-key-value ~/.ssh/id_rsa.pub --network-plugin kubenet --vnet-subnet-id $KUBE_AGENT_SUBNET_ID --docker-bridge-address 172.17.0.1/16 --dns-service-ip 10.2.0.10 --service-cidr 10.2.0.0/24 --pod-cidr 10.244.0.0/16 --client-secret $SERVICE_PRINCIPAL_SECRET --service-principal $SERVICE_PRINCIPAL_ID --kubernetes-version $KUBE_VERSION --enable-rbac --node-vm-size "Standard_D2s_v3" --vm-set-type VirtualMachineScaleSets --load-balancer-sku standard --enable-private-cluster 

az aks nodepool add --name router --resource-group $KUBE_GROUP --cluster-name $KUBE_NAME --aks-custom-headers CustomizedUbuntu=aks-ubuntu-1804,ContainerRuntime=containerd --vnet-subnet-id $KUBE_AGENT2_SUBNET_ID --mode user --labels workload=nonrouter 

az aks nodepool add --name ub1804pip --resource-group $KUBE_GROUP --cluster-name $KUBE_NAME --aks-custom-headers CustomizedUbuntu=aks-ubuntu-1804,ContainerRuntime=containerd --vnet-subnet-id $KUBE_AGENT2_SUBNET_ID

az aks nodepool add --name router --resource-group $KUBE_GROUP --cluster-name $KUBE_NAME --aks-custom-headers CustomizedUbuntu=aks-ubuntu-1804,ContainerRuntime=containerd --vnet-subnet-id $KUBE_AGENT3_SUBNET_ID --mode user --labels workload=router 

```

AKS_CONTROLLER_RESOURCE_ID="$(az identity list -g $KUBE_GROUP --query "[?contains(name, '$KUBE_NAME')].id" -o tsv)"

az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --location $LOCATION --max-pods 250 --node-count 2 --network-plugin azure  --vnet-subnet-id $HOST_VNET_ID  --pod-subnet-id $POD_VNET_ID --kubernetes-version $KUBE_VERSION --docker-bridge-address 172.17.0.1/16 --dns-service-ip 10.2.0.10 --service-cidr 10.2.0.0/24  --no-ssh-key --assign-identity $AKS_CONTROLLER_RESOURCE_ID --enable-managed-identity


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

create private cluster
```

KUBE_AGENT_SUBNET_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$KUBE_GROUP/providers/Microsoft.Network/virtualNetworks/$KUBE_VNET_NAME/subnets/$KUBE_AGENT_SUBNET_NAME"

az aks create \
 --resource-group $KUBE_GROUP \
 --name $KUBE_NAME \
 --node-resource-group $NODE_GROUP \
 --load-balancer-sku standard \
 --enable-private-cluster \
 --network-plugin azure \
 --vnet-subnet-id $KUBE_AGENT_SUBNET_ID \
 --docker-bridge-address 172.17.0.1/16 \
 --dns-service-ip 10.2.0.10 \
 --service-cidr 10.2.0.0/24 \
 --client-secret $SERVICE_PRINCIPAL_SECRET \
 --service-principal $SERVICE_PRINCIPAL_ID

KUBE_AGENT2_SUBNET_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$KUBE_GROUP/providers/Microsoft.Network/virtualNetworks/$KUBE_VNET_NAME/subnets/$KUBE_AGENT2_SUBNET_NAME"

az aks create \
 --resource-group $KUBE_GROUP \
 --name $KUBE_NAME \
 --node-resource-group $NODE_GROUP \
 --load-balancer-sku standard \
 --enable-private-cluster \
 --network-plugin azure \
 --vnet-subnet-id $KUBE_AGENT2_SUBNET_ID \
 --docker-bridge-address 172.17.0.1/16 \
 --dns-service-ip 10.3.0.10 \
 --service-cidr 10.3.0.0/24 \
 --client-secret $SERVICE_PRINCIPAL_SECRET \
 --service-principal $SERVICE_PRINCIPAL_ID

az aks create -n $KUBE_NAME -g $KUBE_GROUP --load-balancer-sku standard --enable-private-cluster --node-resource-group $NODE_GROUP --client-secret $SERVICE_PRINCIPAL_SECRET --service-principal $SERVICE_PRINCIPAL_ID --kubernetes-version $KUBE_VERSION --network-plugin kubenet --vnet-subnet-id $KUBE_AGENT_SUBNET_ID --docker-bridge-address 172.17.0.1/16 --dns-service-ip 10.2.0.10 --service-cidr 10.2.0.0/24

az aks create -g $KUBE_GROUP -n $KUBE_NAME --enable-managed-identity --kubernetes-version $KUBE_VERSION
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
```

create internal load balancer for nginx
```
kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/services/nginx-internal.yaml
```

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


# Peer

```
JUMPBOX_GROUP=jumpbox-we
JUMPBOX_VNET=jumpbox-we-vnet
```


```

az network vnet peering create -g $JUMPBOX_GROUP -n KubeToVMPeer --vnet-name $KUBE_VNET_NAME --remote-vnet $JUMPBOX_VNET --allow-vnet-access

az network vnet peering create -g $JUMPBOX_GROUP -n VMToKubePeer --vnet-name $JUMPBOX_VNET --remote-vnet $KUBE_VNET_NAME --allow-vnet-access

```

# BYO Outbound IP

```

az network public-ip show --resource-group myResourceGroup --name myPublicIP --query id -o tsv


IP="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/aksoutbound/providers/Microsoft.Network/publicIPAddresses/aksoutbound1"
SP_NAME="aksoutbound"
KUBE_GROUP="aksoutbound"

SERVICE_PRINCIPAL_ID=$(az ad sp create-for-rbac --skip-assignment --name $SP_NAME -o json | jq -r '.appId')
echo $SERVICE_PRINCIPAL_ID

SERVICE_PRINCIPAL_SECRET=$(az ad app credential reset --id $SERVICE_PRINCIPAL_ID -o json | jq '.password' -r)
echo $SERVICE_PRINCIPAL_SECRET

az role assignment create --role "Contributor" --assignee $SERVICE_PRINCIPAL_ID -g $KUBE_GROUP

az aks create \
    --resource-group aksoutbound \
    --name myAKSCluster --network-plugin kubenet \
    --client-secret $SERVICE_PRINCIPAL_SECRET --service-principal $SERVICE_PRINCIPAL_ID  \
    --load-balancer-outbound-ips $IP


    service.beta.kubernetes.io/azure-load-balancer-resource-group

    service.beta.kubernetes.io/azure-pip-name

KUBE_NAME=myAKSCluster
KUBE_GROUP=aksoutbound

kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/logging/dummy-logger/depl-logger.yaml

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: dummy-logger-pub-lb
  namespace: default
  annotations:
    service.beta.kubernetes.io/azure-load-balancer-resource-group: aksoutbound
    service.beta.kubernetes.io/azure-pip-name: aksoutbound1
spec:
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: dummy-logger
  type: LoadBalancer
EOF
```


## Pod Subnet

https://ms.portal.azure.com/#@microsoft.onmicrosoft.com/resource/subscriptions/5abd8123-18f8-427f-a4ae-30bfb82617e5/resourceGroups/kubes_fw_knet/overview

KUBE_NAME=dzkubekube-3
LOCATION=westcentralus
KUBE_GROUP=kubes_fw_knet
KUBE_VERSION=1.18.14
NODE_GROUP=kubes_fw_knet_dzkubek

az aks get-credentials -g $KUBE_GROUP -n $KUBE_NAME --admin

ssh dennis@52.161.97.26


az aks command invoke -g $KUBE_GROUP -n $KUBE_NAME$AKS_POSTFIX -c "kubectl get pods -n kube-system"


az aks command invoke -g $KUBE_GROUP -n $KUBE_NAME$AKS_POSTFIX -c "kubectl apply -f deployment.yaml -n default" -f deployment.yaml


az aks command invoke -g $KUBE_GROUP -n $KUBE_NAME$AKS_POSTFIX -c "kubectl apply -f deployment.yaml -n default" -f .


az aks command invoke -g $KUBE_GROUP -n $KUBE_NAME$AKS_POSTFIX -c "helm repo add bitnami https://charts.bitnami.com/bitnami && helm repo update && helm install my-release -f values.yaml bitnami/nginx" -f values.yaml
