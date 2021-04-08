# Create container cluster (AKS)
https://docs.microsoft.com/en-us/azure/aks/kubernetes-walkthrough

0. Variables
```
SUBSCRIPTION_ID=$(az account show --query id -o tsv) # here enter your subscription id
KUBE_GROUP="dzaksaadv2"
KUBE_NAME="aksaad"
KUBE_VERSION="1.18.10" # here enter the kubernetes version of your aks
KUBE_VNET_NAME="spoke1-kubevnet"
KUBE_ING_SUBNET_NAME="ing-1-subnet" # here enter the name of your ingress subnet
KUBE_AGENT_SUBNET_NAME="aks-2-subnet" # here enter the name of your aks subnet
NAT_EGR_SUBNET_NAME="egr-3-subnet" # here enter the name of your egress subnet
LOCATION="australiaeast"
KUBE_VERSION="1.16.7"
AZURE_TENANT_ID=$(az account show --query tenantId -o tsv)
AAD_GROUP_ID=""
```

Select subscription
```
az account set --subscription $SUBSCRIPTION_ID
az group create -n $KUBE_GROUP -l $LOCATION
az network vnet create -g $KUBE_GROUP -n $KUBE_VNET_NAME --address-prefixes 10.0.4.0/22
az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_ING_SUBNET_NAME --address-prefix 10.0.4.0/24
az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_AGENT_SUBNET_NAME --address-prefix 10.0.5.0/24
az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $NAT_EGR_SUBNET_NAME --address-prefix 10.0.6.0/24
KUBE_AGENT_SUBNET_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$KUBE_GROUP/providers/Microsoft.Network/virtualNetworks/$KUBE_VNET_NAME/subnets/$KUBE_AGENT_SUBNET_NAME"
EGRESS_AGENT_SUBNET_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$KUBE_GROUP/providers/Microsoft.Network/virtualNetworks/$KUBE_VNET_NAME/subnets/$NAT_EGR_SUBNET_NAME"
NODE_GROUP=$KUBE_GROUP"_"$KUBE_NAME"_nodes_"$LOCATION # name of the node resource group
```

get available version
```
az aks get-versions -l $LOCATION -o table
```

2. Create the aks cluster
```
az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --node-resource-group $NODE_GROUP --load-balancer-sku standard --enable-vmss --network-plugin kubenet --vnet-subnet-id $KUBE_AGENT_SUBNET_ID --docker-bridge-address 172.17.0.1/16 --dns-service-ip 10.2.0.10 --service-cidr 10.2.0.0/24 --enable-managed-identity --kubernetes-version $KUBE_VERSION --enable-aad --aad-admin-group-object-ids $AAD_GROUP_ID --aad-tenant-id $AZURE_TENANT_ID --uptime-sla
```

az aks nodepool add -g $KUBE_GROUP --cluster-name $KUBE_NAME -n gpu2pool -c 1 --node-vm-size Standard_D2_v2 --mode user --vnet-subnet-id $EGRESS_AGENT_SUBNET_ID


with existing keys and latest version
```
SMSI_SERVICE_PRINCIPAL_ID=$(az aks show --resource-group $KUBE_GROUP --name $KUBE_NAME --query "identity.principalId" -o tsv )
az role assignment create --role "Contributor" --assignee $SMSI_SERVICE_PRINCIPAL_ID -g $VNET_GROUP
```

with existing service principal

```
az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --node-count 3  --ssh-key-value ~/.ssh/id_rsa.pub --kubernetes-version $KUBE_VERSION --client-secret $SERVICE_PRINCIPAL_SECRET --service-principal $SERVICE_PRINCIPAL_ID --enable-addons http_application_routing
```

with rbac (is now default)

```
az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --node-count 3  --ssh-key-value ~/.ssh/id_rsa.pub --kubernetes-version $KUBE_VERSION --enable-rbac --aad-server-app-id $AAD_APP_ID --aad-server-app-secret $AAD_APP_SECRET --aad-client-app-id $AAD_CLIENT_ID --aad-tenant-id $TENANT_ID --client-secret $SERVICE_PRINCIPAL_SECRET --service-principal $SERVICE_PRINCIPAL_ID --node-vm-size "Standard_B1ms" --enable-addons http_application_routing monitoring

az aks create \
    --resource-group $KUBE_GROUP \
    --name $KUBE_NAME \
    --enable-vmss \
    --node-count 1 \
    --ssh-key-value ~/.ssh/id_rsa.pub \
    --kubernetes-version $KUBE_VERSION \
    --enable-rbac \
    --enable-addons monitoring
```

without rbac ()
```
--disable-rbac
```

show deployment
```
az aks show --resource-group $KUBE_GROUP --name $KUBE_NAME
```

deactivate routing addon
```
az aks disable-addons --addons http_application_routing --resource-group $KUBE_GROUP --name $KUBE_NAME
```

az aks enable-addons \
    --resource-group $KUBE_GROUP \
    --name $KUBE_NAME \
    --addons virtual-node \
    --subnet-name aci-2-subnet

# deploy zones, msi, slb via arm
```
az group create -n $KUBE_GROUP -l $LOCATION

az group deployment create \
    --name spot \
    --resource-group $KUBE_GROUP \
    --template-file "arm/spot_template.json" \
    --parameters "arm/spot_parameters.json" \
    --parameters "resourceName=$KUBE_NAME" \
        "location=$LOCATION" \
        "dnsPrefix=$KUBE_NAME" \
        "kubernetesVersion=$KUBE_VERSION" \
        "servicePrincipalClientId=$SERVICE_PRINCIPAL_ID" \
        "servicePrincipalClientSecret=$SERVICE_PRINCIPAL_SECRET"
```

3. Export the kubectrl credentials files
```
az aks get-credentials --resource-group=$KUBE_GROUP --name=$KUBE_NAME
```

or If you are not using the Azure Cloud Shell and don’t have the Kubernetes client kubectl, run 
```
az aks install-cli
```

or download the file manually
```
scp azureuser@($KUBE_NAME)mgmt.westeurope.cloudapp.azure.com:.kube/config $HOME/.kube/config
```

4. Check that everything is running ok
```
kubectl version
kubectl config current-contex
```

Use flag to use context
```
kubectl --kube-context
```

5. Activate the kubernetes dashboard
```
az aks browse --resource-group=$KUBE_GROUP --name=$KUBE_NAME
http://localhost:8001/api/v1/namespaces/kube-system/services/kubernetes-dashboard/proxy/#!/login
```

6. Get all upgrade versions
```
az aks get-upgrades --resource-group=$KUBE_GROUP --name=$KUBE_NAME --output table
```

7. Perform upgrade
```
az aks upgrade --resource-group=$KUBE_GROUP --name=$KUBE_NAME --kubernetes-version 1.10.6
```

# Add agent pool

```
az aks enable-addons \
    --resource-group $KUBE_GROUP \
    --name $KUBE_NAME \
    --addons virtual-node \
    --subnet-name aci-2-subnet

az aks disable-addons --resource-group $KUBE_GROUP --name $KUBE_NAME --addons virtual-node


cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: aci-helloworld
spec:
  replicas: 1
  selector:
    matchLabels:
      app: aci-helloworld
  template:
    metadata:
      labels:
        app: aci-helloworld
    spec:
      containers:
      - name: aci-helloworld
        image: microsoft/aci-helloworld
        ports:
        - containerPort: 80
      nodeSelector:
        kubernetes.io/role: agent
        beta.kubernetes.io/os: linux
        type: virtual-kubelet
      tolerations:
      - key: virtual-kubelet.io/provider
        operator: Exists
      - key: azure.com/aci
        effect: NoSchedule
EOF

az aks nodepool add -g $KUBE_GROUP --cluster-name $KUBE_NAME -n linuxpool2 -c 1
az aks nodepool add -g $KUBE_GROUP --cluster-name $KUBE_NAME --os-type Windows -n winpoo -c 1 --node-vm-size Standard_D2_v2

az aks nodepool list -g $KUBE_GROUP --cluster-name $KUBE_NAME -o table

az aks nodepool scale -g $KUBE_GROUP --cluster-name $KUBE_NAME  -n cheap -c 1
az aks nodepool scale -g $KUBE_GROUP --cluster-name $KUBE_NAME  -n agentpool -c 1
```

# autoscaler
https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/FAQ.md#im-running-cluster-with-nodes-in-multiple-zones-for-ha-purposes-is-that-supported-by-cluster-autoscaler

```
az aks nodepool scale -g $KUBE_GROUP --cluster-name $KUBE_NAME  -n agentpool1 -c 1
az aks nodepool update --resource-group $KUBE_GROUP --cluster-name $KUBE_NAME --name agentpool1 --enable-cluster-autoscaler --min-count 1 --max-count 3

```

```
kubectl -n kube-system describe configmap cluster-autoscaler-status
```

# Create SSH access
https://docs.microsoft.com/en-us/azure/aks/ssh

```
NODE_GROUP=$(az aks show --resource-group $KUBE_GROUP --name $KUBE_NAME --query nodeResourceGroup -o tsv)
SCALE_SET_NAME=$(az vmss list --resource-group $NODE_GROUP --query [0].name -o tsv)

az vmss list-instances --resource-group kub_ter_a_m_dapr5_nodes_northeurope --name aks-default-33188643-vmss --query '[].[name, storageProfile.dataDisks[]]' | less

az vmss extension set  \
    --resource-group $NODE_GROUP \
    --vmss-name $SCALE_SET_NAME \
    --name VMAccessForLinux \
    --publisher Microsoft.OSTCExtensions \
    --version 1.4 \
    --protected-settings "{\"username\":\"dennis\", \"ssh_key\":\"$(cat ~/.ssh/id_rsa.pub)\"}"

az vmss update-instances --instance-ids '*' \
  --resource-group $NODE_GROUP \
  --name $SCALE_SET_NAME

kubectl run -it --rm aks-ssh --image=debian

kubectl -n test exec -it $(kubectl -n test get pod -l run=aks-ssh -o jsonpath='{.items[0].metadata.name}') -- /bin/sh

kubectl cp ~/.ssh/id_rsa $(kubectl get pod -l run=aks-ssh -o jsonpath='{.items[0].metadata.name}'):/id_rsa

```

# Delete everything
```
az group delete -n $KUBE_GROUP
```




echo "retrieving login credentials"
export TENANT_ID=$(cat /host/azure.json | jq -r ".[0].tenantId" )
export SUBSCRIPTION_ID=$(cat /host/azure.json | jq -r ".[0].subscriptionId" )
export CLIENT_ID=$(cat /host/azure.json | jq -r ".[0].aadClientId" )
export CLIENT_SECRET=$(cat /host/azure.json | jq -r ".[0].aadClientSecret" )
az login --service-principal --username $CLIENT_ID --password $CLIENT_SECRET --tenant $TENANT_ID

az role assignment list --assignee CLIENT_ID


## Kubernetes AAD RBAC

https://docs.microsoft.com/en-us/azure/aks/manage-azure-rbac
KUBE_GROUP="dzaksaadv2"
KUBE_NAME="aksaad"
LOCATION="westus2"
AZURE_TENANT_ID=$(az account show --query tenantId -o tsv)
AAD_GROUP_ID=""

az group create -n $KUBE_GROUP -l $LOCATION

az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --vm-set-type VirtualMachineScaleSets \
    --load-balancer-sku standard \
    --node-count 1 --enable-managed-identity \
    --enable-aad --enable-azure-rbac

AKS_ID=$(az aks show -g $KUBE_GROUP -n $KUBE_NAME --query id -o tsv)

az aks get-credentials -g $KUBE_GROUP -n $KUBE_NAME --admin

kubectl create ns aadsecured

kubectl run --generator=run-pod/v1 --image=k8s.gcr.io/echoserver:1.10 echoserver --port=80 -n aadsecured
kubectl run --generator=run-pod/v1 --image=nginx nginx --port=80 -n aadsecured
kubectl create secret generic azure-secret --from-literal accountname=dzpremium1 --from-literal accountkey="QmJPk8fBkpLbK1wCjrNvYSVFFIb9sCT9GI7QeAkURJZEIjKecMYA4HC0saEJmj9u6jRiB+Tp6hNhuoBOYnDVLQ==" --type=Opaque -n aadsecured


az role assignment create --role "Azure Kubernetes Service RBAC Admin" --assignee $MY_USER_ID --scope $AKS_ID

az role assignment create --role "Azure Kubernetes Service RBAC Reader" --assignee $MY_USER_ID --scope $AKS_ID/namespaces/default

az role assignment create --role "Azure Kubernetes Service RBAC Reader" --assignee $MY_USER_ID --scope $AKS_ID/namespaces/aadsecured

az aks update --resource-group $KUBE_GROUP --name $KUBE_NAME --aad-admin-group-object-ids $AAD_GROUP_ID

kubectl get pod -n aadsecured

KUBE_NAME=dzuserauth

AKS_ID=$(az aks show -g MyResourceGroup -n MyManagedCluster --query id -o tsv)

az aks get-credentials -g MyResourceGroup -n MyManagedCluster --admin

az role assignment create --role "Azure Kubernetes Service RBAC Viewer" --assignee $MY_USER_ID --scope $AKS_ID/namespaces/aadsecured


az role assignment create --role "Azure Kubernetes Service RBAC Reader" --assignee $MY_USER_ID --scope $AKS_ID/namespaces/aadsecured

az aks update --enable-pod-identity --resource-group $KUBE_GROUP --name $KUBE_NAME


SERVICE_PRINCIPAL_ID=$(az ad sp create-for-rbac --skip-assignment --name $KUBE_NAME-sp -o json | jq -r '.appId')
echo $SERVICE_PRINCIPAL_ID

SERVICE_PRINCIPAL_SECRET=$(az ad app credential reset --id $SERVICE_PRINCIPAL_ID -o json | jq '.password' -r)
echo $SERVICE_PRINCIPAL_SECRET

KUBE_NAME=MyManagedCluster
KUBE_GROUP=myResourceGroup

az aks get-credentials -g MyResourceGroup -n MyManagedCluster

SERVICE_PRINCIPAL_ID=
SERVICE_PRINCIPAL_SECRET=
AZURE_TENANT_ID=

az login --service-principal -u $SERVICE_PRINCIPAL_ID -p $SERVICE_PRINCIPAL_SECRET --tenant $AZURE_TENANT_ID
az role assignment create --role "Azure Kubernetes Service RBAC Reader" --assignee "$SERVICE_PRINCIPAL_ID" --scope $AKS_ID/namespaces/aadsecured


wget https://github.com/Azure/kubelogin/releases/download/v0.0.6/kubelogin-linux-amd64.zip
unzip kubelogin-linux-amd64.zip -d kubetools

export KUBECONFIG=/home/dennis/.kube/config

az aks get-credentials -g MyResourceGroup -n MyManagedCluster

rm /home/dennis/.kube/config
touch /home/dennis/.kube/config

kubelogin convert-kubeconfig -l ropc


export AAD_USER_PRINCIPAL_NAME=
export AAD_SERVICE_PRINCIPAL_CLIENT_ID=
export AAD_SERVICE_PRINCIPAL_CLIENT_SECRET=
export AAD_USER_PRINCIPAL_PASSWORD=

kubectl get no
``` 


SUBSCRIPTION_ID=$(az account show --query id -o tsv) # here enter your subscription id
KUBE_GROUP="kub_ter_a_m_dzarc1"
KUBE_NAME="dzarc1"
LOCATION="westeurope"
KUBE_VERSION="1.16.13"
KUBE_VNET_NAME="dzarc1-vnet"
KUBE_AGENT_SUBNET_NAME="aks-5-subnet"
KUBE_AGENT_SUBNET_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$KUBE_GROUP/providers/Microsoft.Network/virtualNetworks/$KUBE_VNET_NAME/subnets/$KUBE_AGENT_SUBNET_NAME"

NODE_GROUP=$KUBE_GROUP"_"$KUBE_NAME"_nodes_"$LOCATION 

az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --node-resource-group $NODE_GROUP --load-balancer-sku standard --enable-vmss --network-plugin azure  --docker-bridge-address 172.17.0.1/16 --dns-service-ip 10.2.0.10 --service-cidr 10.2.0.0/24 --enable-managed-identity --kubernetes-version $KUBE_VERSION  --uptime-sla  --enable-aad --enable-azure-rbac
--vnet-subnet-id $KUBE_AGENT_SUBNET_ID   

AKS_ID=$(az aks show -g $KUBE_GROUP -n $KUBE_NAME --query id -o tsv)

az role assignment create --role "Azure Kubernetes Service RBAC Admin" --assignee $MY_USER_ID --scope $AKS_ID


## AAD Pod Identity

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
IDENTITY_NAME=podidentity1
POD_IDENTITY_NAME="my-pod-identity"
POD_IDENTITY_NAMESPACE="my-app"
NODE_GROUP=$(az aks show --resource-group $KUBE_GROUP --name $KUBE_NAME --query nodeResourceGroup -o tsv)

az identity create --resource-group ${NODE_GROUP} --name ${IDENTITY_NAME}
IDENTITY_CLIENT_ID="$(az identity show -g ${NODE_GROUP} -n ${IDENTITY_NAME} --query clientId -o tsv)"
IDENTITY_RESOURCE_ID="$(az identity show -g ${NODE_GROUP} -n ${IDENTITY_NAME} --query id -o tsv)"

az aks update --resource-group $KUBE_GROUP --name $KUBE_NAME --enable-pod-identity

kubectl create namespace $POD_IDENTITY_NAMESPACE

az aks pod-identity add --resource-group ${KUBE_GROUP} --cluster-name ${KUBE_NAME} --namespace ${POD_IDENTITY_NAMESPACE}  --name ${POD_IDENTITY_NAME} --identity-resource-id ${IDENTITY_RESOURCE_ID}

az role assignment create --role "Reader" --assignee "cd74751b-ed09-421a-9001-807cddbb29de" --scope /subscriptions/$SUBSCRIPTION_ID/resourcegroups/$NODE_GROUP

az role assignment create --role "Reader" --assignee "$IDENTITY_CLIENT_ID" --scope /subscriptions/$SUBSCRIPTION_ID/resourcegroups/$NODE_GROUP


https://azure.github.io/aad-pod-identity/docs/configure/pod_identity_in_managed_mode/

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: demo
  labels:
    aadpodidbinding: $POD_IDENTITY_NAME
  namespace: $POD_IDENTITY_NAMESPACE
spec:
  containers:
  - name: demo
    image: mcr.microsoft.com/oss/azure/aad-pod-identity/demo:v1.6.3
    args:
      - --subscriptionid=$SUBSCRIPTION_ID
      - --clientid=$IDENTITY_CLIENT_ID
      - --resourcegroup=$NODE_GROUP
    env:
      - name: MY_POD_NAME
        valueFrom:
          fieldRef:
            fieldPath: metadata.name
      - name: MY_POD_NAMESPACE
        valueFrom:
          fieldRef:
            fieldPath: metadata.namespace
      - name: MY_POD_IP
        valueFrom:
          fieldRef:
            fieldPath: status.podIP
  nodeSelector:
    kubernetes.io/os: linux
EOF

kubectl logs demo --follow --namespace my-app
