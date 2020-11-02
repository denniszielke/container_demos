# Installing virtual kubelet

https://github.com/virtual-kubelet/virtual-kubelet
https://github.com/virtual-kubelet/azure-aci/blob/master/README.md

0. Variables
```
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
KUBE_GROUP=kubes-aci
KUBE_NAME=dzkubaci
LOCATION=westeurope
KUBE_VERSION="$(az aks get-versions -l $LOCATION --query 'orchestrators[?default == `true`].orchestratorVersion' -o tsv)"
```

1. create aci resource group
```
az group create --name $KUBE_GROUP --location $LOCATION

az network vnet create -g $KUBE_GROUP -n $KUBE_NAME-vnet
az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_NAME-vnet -n gw-subnet --address-prefix 10.0.1.0/24
az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_NAME-vnet -n aci-subnet --address-prefix 10.0.2.0/24 --service-endpoints Microsoft.Sql Microsoft.AzureCosmosDB Microsoft.KeyVault
az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_NAME-vnet -n aks-subnet --address-prefix 10.0.5.0/24 --service-endpoints Microsoft.Sql Microsoft.AzureCosmosDB Microsoft.KeyVault Microsoft.Storage
```

2. install connector
```

KUBE_AGENT_SUBNET_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$KUBE_GROUP/providers/Microsoft.Network/virtualNetworks/$KUBE_NAME-vnet/subnets/aks-subnet"

az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --vm-set-type VirtualMachineScaleSets --load-balancer-sku standard --kubernetes-version $KUBE_VERSION \
    --node-count 3 --enable-managed-identity  --enable-rbac --enable-addons monitoring --enable-vmss --network-plugin azure --vnet-subnet-id $KUBE_AGENT_SUBNET_ID --docker-bridge-address 172.17.0.1/16 --service-cidr 10.2.0.0/24 --dns-service-ip 10.2.0.10

az aks install-connector --resource-group $KUBE_GROUP --name $KUBE_NAME --aci-resource-group $ACI_GROUP
 
az aks enable-addons \
    --resource-group $KUBE_GROUP \
    --name $KUBE_NAME \
    --addons virtual-node \
    --subnet-name aci-subnet

az aks disable-addons --resource-group $KUBE_GROUP --name $KUBE_NAME --addons virtual-node
```

Install open source virtual kubelet
```
SERVICE_PRINCIPAL_ID=$(az ad sp create-for-rbac --skip-assignment --name $KUBE_NAME-sp -o json | jq -r '.appId')
echo $SERVICE_PRINCIPAL_ID

SERVICE_PRINCIPAL_SECRET=$(az ad app credential reset --id $SERVICE_PRINCIPAL_ID -o json | jq '.password' -r)
echo $SERVICE_PRINCIPAL_SECRET
TENANT_ID=$(az account show --query tenantId -o tsv)
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

az role assignment create --role "Contributor" --assignee $SERVICE_PRINCIPAL_ID -g $KUBE_GROUP

export VK_RELEASE=virtual-kubelet-latest
export MASTER_URI=https://dzkubaci-kubes-aci-5abd81-6d74b9ff.hcp.westeurope.azmk8s.io:443
export RELEASE_NAME=virtual-kubelet
export VK_RELEASE=virtual-kubelet-latest
export NODE_NAME=virtual-kubelet
export CHART_URL=https://github.com/virtual-kubelet/azure-aci/raw/master/charts/$VK_RELEASE.tgz

helm install "$RELEASE_NAME" "$CHART_URL" \
  --set provider=azure \
  --set providers.azure.targetAKS=false \
  --set providers.azure.masterUri=$MASTER_URI \
  --set providers.azure.vnet.enabled=false \
  --set providers.azure.clientId=$SERVICE_PRINCIPAL_ID \
  --set providers.azure.clientKey=$SERVICE_PRINCIPAL_SECRET \
  --set providers.azure.tenantId=$TENANT_ID \
  --set providers.azure.subscriptionId=$SUBSCRIPTION_ID \
  --set providers.azure.aciResourceGroup=$KUBE_GROUP \
  --set providers.azure.aciRegion=$LOCATION 
```

3. schedule pod on virtual node

```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: helloworld1
spec:
  containers:
  - image: microsoft/aci-helloworld
    imagePullPolicy: Always
    name: helloworld
    resources:
      requests:
        memory: 1G
        cpu: 1
    ports:
    - containerPort: 80
      name: http
      protocol: TCP
    - containerPort: 443
      name: https
  dnsPolicy: ClusterFirst
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
```

```
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
        resources:
          limits:
           nvidia.com/gpu: 1
      nodeSelector:
        kubernetes.io/hostname: virtual-node-aci-linux-helm 
      tolerations:
      - key: virtual-kubelet.io/provider
        operator: Equal
        value: azure
        effect: NoSchedule
EOF
```
4. clean up
```
kubectl delete pods,services -l app=hello-app

kubectl delete pods,services -l pod-template-hash=916745872
```