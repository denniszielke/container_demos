# Installing virtual kubelet

https://github.com/virtual-kubelet/virtual-kubelet
https://github.com/virtual-kubelet/azure-aci/blob/master/README.md
https://github.com/virtual-kubelet/azure-aci/blob/master/README.md#manual-set-up

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
KUBE_VNET_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$KUBE_GROUP/providers/Microsoft.Network/virtualNetworks/$KUBE_NAME-vnet

SERVICE_PRINCIPAL_ID=$(az ad sp create-for-rbac --skip-assignment --name $KUBE_NAME-sp -o json | jq -r '.appId')
echo $SERVICE_PRINCIPAL_ID

SERVICE_PRINCIPAL_SECRET=$(az ad app credential reset --id $SERVICE_PRINCIPAL_ID -o json | jq '.password' -r)
echo $SERVICE_PRINCIPAL_SECRET

az role assignment create --role "Contributor" --assignee $SERVICE_PRINCIPAL_ID -g $KUBE_GROUP

az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --vm-set-type VirtualMachineScaleSets --load-balancer-sku standard --kubernetes-version $KUBE_VERSION \
    --node-count 3 --client-secret $SERVICE_PRINCIPAL_SECRET --service-principal $SERVICE_PRINCIPAL_ID  --enable-rbac --enable-addons monitoring --enable-vmss --network-plugin azure --vnet-subnet-id $KUBE_AGENT_SUBNET_ID --docker-bridge-address 172.17.0.1/16 --service-cidr 10.2.0.0/24 --dns-service-ip 10.2.0.10


az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --vm-set-type VirtualMachineScaleSets --load-balancer-sku standard --kubernetes-version $KUBE_VERSION \
    --node-count 3 --enable-managed-identity  --enable-rbac --enable-addons monitoring --enable-vmss --network-plugin azure --vnet-subnet-id $KUBE_AGENT_SUBNET_ID --docker-bridge-address 172.17.0.1/16 --service-cidr 10.2.0.0/24 --dns-service-ip 10.2.0.10

KUBELET_ID=$(az aks show -g $KUBE_GROUP -n $KUBE_NAME --query identityProfile.kubeletidentity.clientId -o tsv)
CONTROLLER_ID=$(az aks show -g $KUBE_GROUP -n $KUBE_NAME --query identity.principalId -o tsv)
NODE_GROUP=$(az aks show --resource-group $KUBE_GROUP --name $KUBE_NAME --query nodeResourceGroup -o tsv)

az role assignment create --role "Contributor" --assignee $SERVICE_PRINCIPAL_ID --scope /subscriptions/$SUBSCRIPTION_ID/resourcegroups/$NODE_GROUP



az role assignment create --role "Contributor" --assignee $CONTROLLER_ID --scope /subscriptions/$SUBSCRIPTION_ID/resourcegroups/$NODE_GROUP
az role assignment create --role "Contributor" --assignee $CONTROLLER_ID --scope $KUBE_VNET_ID

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

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: job-claim
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 100Gi
  storageClassName: azurefile
EOF

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
        kubernetes.io/hostname: virtual-node-aci-linux
      tolerations:
      - key: virtual-kubelet.io/provider
        operator: Equal
        value: azure
        effect: NoSchedule
EOF

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: aci-helloworldnode
spec:
  replicas: 1
  selector:
    matchLabels:
      app: aci-helloworldnode
  template:
    metadata:
      labels:
        app: aci-helloworldnode
    spec:
      containers:
      - name: aci-helloworldnode
        image: microsoft/aci-helloworld
        ports:
        - containerPort: 80
        volumeMounts:
          - name: files
            mountPath: /mnt/azure
      volumes:
      - name: files
        azureFile:
          shareName: "job"
          readOnly: false
          secretName: azurefile-secret
EOF


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
        volumeMounts:
          - name: files
            mountPath: /mnt/azure
      nodeSelector:
        kubernetes.io/hostname: virtual-node-aci-linux
      tolerations:
      - key: virtual-kubelet.io/provider
        operator: Equal
        value: azure
        effect: NoSchedule
      volumes:
      - name: files
        azureFile:
          shareName: "job"
          readOnly: false
          secretName: azurefile-secret
EOF

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: aci-helloworldv1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: aci-helloworldv1
  template:
    metadata:
      labels:
        app: aci-helloworldv1
    spec:
      containers:
      - name: aci-helloworldv1
        image: microsoft/aci-helloworld
        ports:
        - containerPort: 80
        volumeMounts:
          - name: files
            mountPath: /mnt/azure
      nodeSelector:
        kubernetes.io/hostname: virtual-node-aci-linux
      tolerations:
      - key: virtual-kubelet.io/provider
        operator: Equal
        value: azure
        effect: NoSchedule
      volumes:
      - name: files
        azureFile:
          shareName: "job"
          readOnly: false
          secretName: azurefilev1-secret
EOF

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: aci-helloworldnodev1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: aci-helloworldnodev1
  template:
    metadata:
      labels:
        app: aci-helloworldnodev1
    spec:
      containers:
      - name: aci-helloworldnodev1
        image: microsoft/aci-helloworld
        ports:
        - containerPort: 80
        volumeMounts:
          - name: files
            mountPath: /mnt/azure
      volumes:
      - name: files
        azureFile:
          shareName: "job"
          readOnly: false
          secretName: azurefilev1-secret
EOF
```
4. clean up
```
kubectl delete pods,services -l app=hello-app

kubectl delete pods,services -l pod-template-hash=916745872
```


## Storage

```

STORAGE_ACCOUNT=$KUBE_NAME

NODE_GROUP=$(az aks show --resource-group $KUBE_GROUP --name $KUBE_NAME --query nodeResourceGroup -o tsv) 

az storage account create --resource-group  $NODE_GROUP --name $STORAGE_ACCOUNT --location $LOCATION --sku Standard_LRS --kind StorageV2 --access-tier hot --https-only false


STORAGE_KEY=$(az storage account keys list --account-name $STORAGE_ACCOUNT --resource-group $NODE_GROUP --query "[0].value")


az storage share create -n job --quota 10 --account-name $STORAGE_ACCOUNT --account-key $STORAGE_KEY
 

kubectl create secret generic azurefile-secret --from-literal=azurestorageaccountname=$STORAGE_ACCOUNT --from-literal=azurestorageaccountkey=$STORAGE_KEY


STORAGE_ACCOUNT=dzstorv1

NODE_GROUP=$(az aks show --resource-group $KUBE_GROUP --name $KUBE_NAME --query nodeResourceGroup -o tsv) 

az storage account create --resource-group  $NODE_GROUP --name $STORAGE_ACCOUNT --location $LOCATION --sku Standard_LRS --kind Storage --https-only false


STORAGE_KEY=$(az storage account keys list --account-name $STORAGE_ACCOUNT --resource-group $NODE_GROUP --query "[0].value")


az storage share create -n job --quota 10 --account-name $STORAGE_ACCOUNT --account-key $STORAGE_KEY
 

kubectl create secret generic azurefilev1-secret --from-literal=azurestorageaccountname=$STORAGE_ACCOUNT --from-literal=azurestorageaccountkey=$STORAGE_KEY

```

##  AGIC

```

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: aci-helloworld-blue
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
        image: denniszielke/blue
        ports:
        - containerPort: 80
      nodeSelector:
        kubernetes.io/role: agent
        beta.kubernetes.io/os: linux
        type: virtual-kubelet
      tolerations:
      - key: virtual-kubelet.io/provider
        operator: Exists
EOF

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: aci-helloworld-green
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
        image: denniszielke/green
        ports:
        - containerPort: 80
      nodeSelector:
        kubernetes.io/role: agent
        beta.kubernetes.io/os: linux
        type: virtual-kubelet
      tolerations:
      - key: virtual-kubelet.io/provider
        operator: Exists
EOF

kubectl expose deployment aci-helloworld-green --type=LoadBalancer --port=80

cat <<EOF | kubectl apply -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: aci-helloworld-green
  annotations:
    kubernetes.io/ingress.class: azure/application-gateway
spec:
  rules:
  - http:
      paths:
      - backend:
          serviceName: aci-helloworld-green
          servicePort: 80
EOF

```
