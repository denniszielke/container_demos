# Create container cluster (AKS)
https://docs.microsoft.com/en-us/azure/aks/kubernetes-walkthrough

0. Variables
```
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)
KUBE_GROUP="akssimple"
KUBE_NAME="aksrouter"
LOCATION="westeurope"
KUBE_VERSION="$(az aks get-versions -l $LOCATION --query 'orchestrators[?default == `true`].orchestratorVersion' -o tsv)"
REGISTRY_NAME=""
APPINSIGHTS_KEY=""

SERVICE_PRINCIPAL_ID=
SERVICE_PRINCIPAL_SECRET=

SERVICE_PRINCIPAL_ID=$(az ad sp create-for-rbac --skip-assignment --name $KUBE_NAME-sp -o json | jq -r '.appId')
echo $SERVICE_PRINCIPAL_ID

SERVICE_PRINCIPAL_SECRET=$(az ad app credential reset --id $SERVICE_PRINCIPAL_ID -o json | jq '.password' -r)
echo $SERVICE_PRINCIPAL_SECRET

az ad sp create-for-rbac --sdk-auth

```

Select subscription
```
az account set --subscription $SUBSCRIPTION_ID
```

1. Create the resource group
```
az group create -n $KUBE_GROUP -l $LOCATION
```

get available version
```
az aks get-versions -l $LOCATION -o table
```

2. Create the aks cluster
```

KUBE_AGENT_SUBNET_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$KUBE_VNET_GROUP/providers/Microsoft.Network/virtualNetworks/$KUBE_VNET_NAME/subnets/$KUBE_AGENT_SUBNET_NAME"

az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --node-count 3 --generate-ssh-keys --kubernetes-version $KUBE_VERSION

az aks create -g $KUBE_GROUP -n $KUBE_NAME --kubernetes-version $KUBE_VERSION --node-count 1 --client-secret $SERVICE_PRINCIPAL_SECRET --service-principal $SERVICE_PRINCIPAL_ID --kubernetes-version $KUBE_VERSION

az aks create -g $KUBE_GROUP -n $KUBE_NAME --kubernetes-version $KUBE_VERSION --node-count 1 --enable-cluster-autoscaler --min-count 1 --max-count 3  --client-secret $SERVICE_PRINCIPAL_SECRET --service-principal $SERVICE_PRINCIPAL_ID --kubernetes-version $KUBE_VERSION  --enable-vmss

az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --network-plugin azure --vm-set-type VirtualMachineScaleSets --load-balancer-sku standard --kubernetes-version $KUBE_VERSION \
    --node-count 1 --enable-managed-identity --enable-node-public-ip --ssh-key-value ~/.ssh/id_rsa.pub --aks-custom-headers CustomizedUbuntu=aks-ubuntu-1804,ContainerRuntime=containerd --node-resource-group $KUBE_GROUP"_"$KUBE_NAME"_nodes_"$LOCATION --vnet-subnet-id $KUBE_AGENT_SUBNET_ID  --docker-bridge-address 172.17.0.1/16 --dns-service-ip 10.2.0.10 --service-cidr 10.2.0.0/24

az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --network-plugin azure --vm-set-type VirtualMachineScaleSets --load-balancer-sku standard --kubernetes-version $KUBE_VERSION \
    --node-count 3 --enable-managed-identity --enable-node-public-ip --ssh-key-value ~/.ssh/id_rsa.pub --aks-custom-headers EnableAzureDiskFileCSIDriver=true   --node-resource-group $KUBE_GROUP"_"$KUBE_NAME"_nodes_"$LOCATION --vnet-subnet-id $KUBE_AGENT_SUBNET_ID  --docker-bridge-address 172.17.0.1/16 --dns-service-ip 10.2.0.10 --service-cidr 10.2.0.0/24

az aks nodepool add --name ubuntu1804 --resource-group $KUBE_GROUP --cluster-name $KUBE_NAME --enable-node-public-ip --aks-custom-headers CustomizedUbuntu=aks-ubuntu-1804,ContainerRuntime=containerd

az aks nodepool add --name ubuntucsi --resource-group $KUBE_GROUP --cluster-name $KUBE_NAME --aks-custom-headers CustomizedUbuntu=aks-ubuntu-1804,ContainerRuntime=containerd,EnableAzureDiskFileCSIDriver=true

az aks nodepool add --name ub1804pip --resource-group $KUBE_GROUP --cluster-name $KUBE_NAME --enable-node-public-ip --aks-custom-headers CustomizedUbuntu=aks-ubuntu-1804 --vnet-subnet-id $KUBE_AGENT_SUBNET_ID

az aks update --enable-cluster-autoscaler --min-count 1 --max-count 5 -g $KUBE_GROUP -n $KUBE_NAME

az aks update -g $KUBE_GROUP -n $KUBE_NAME --auto-upgrade-channel rapid

```

with existing keys and latest version
```
az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --node-count 3  --ssh-key-value ~/.ssh/id_rsa.pub --kubernetes-version $KUBE_VERSION --enable-addons http_application_routing
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

az group deployment create \
    --name spot \
    --resource-group $KUBE_GROUP \
    --template-file "arm/azurecni_template.json" \
    --parameters "arm/azurecni_parameters.json" \
    --parameters "resourceName=$KUBE_NAME" \
        "location=$LOCATION" \
        "dnsPrefix=$KUBE_NAME" \
        "kubernetesVersion=$KUBE_VERSION" \
        "vnetSubnetID=$KUBE_AGENT_SUBNET_ID"
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

az aks nodepool add -g $KUBE_GROUP --cluster-name $KUBE_NAME -n gpu1pool -c 1 --node-vm-size Standard_NC6 --mode user
az aks nodepool scale -g $KUBE_GROUP --cluster-name $KUBE_NAME -n gpu1pool -c 0 
SCALE_SET_NAME=$(az vmss list --resource-group $NODE_GROUP --query [0].name -o tsv)
az vmss scale --name $SCALE_SET_NAME --new-capacity 0 --resource-group $NODE_GROUP


az aks nodepool scale -g $KUBE_GROUP --cluster-name $KUBE_NAME  -n gpupool -c 0
az aks nodepool delete -g $KUBE_GROUP --cluster-name $KUBE_NAME -n gpupool

az aks nodepool add -g $KUBE_GROUP --cluster-name $KUBE_NAME -n mynodepool --mode system


az aks nodepool add -g $KUBE_GROUP --cluster-name $KUBE_NAME -n linuxpool2 -c 1

az aks nodepool add -g $KUBE_GROUP --cluster-name $KUBE_NAME -n scalingpool -c 0 --enable-cluster-autoscaler --min-count 0 --max-count 3
az aks nodepool add -g $KUBE_GROUP --cluster-name $KUBE_NAME --os-type Windows -n winpoo -c 1 --node-vm-size Standard_D2_v2

az aks nodepool list -g $KUBE_GROUP --cluster-name $KUBE_NAME -o table

az aks nodepool scale -g $KUBE_GROUP --cluster-name $KUBE_NAME  -n scalingpool -c 0
az aks nodepool scale -g $KUBE_GROUP --cluster-name $KUBE_NAME  -n cheap -c 1
az aks nodepool scale -g $KUBE_GROUP --cluster-name $KUBE_NAME  -n agentpool -c 1
```

# autoscaler
https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/FAQ.md#im-running-cluster-with-nodes-in-multiple-zones-for-ha-purposes-is-that-supported-by-cluster-autoscaler

https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/cloudprovider/azure/README.md

```
az aks nodepool scale -g $KUBE_GROUP --cluster-name $KUBE_NAME  -n agentpool1 -c 1
az aks nodepool update --resource-group $KUBE_GROUP --cluster-name $KUBE_NAME --name agentpool1 --enable-cluster-autoscaler --min-count 1 --max-count 3

```

```
az aks nodepool add -g $KUBE_GROUP --cluster-name $KUBE_NAME -n gpuworkers -c 1 --mode user --labels workload=zeroscaler --node-taints expensive=true:NoSchedule  --node-vm-size Standard_NC6

az aks nodepool delete -g $KUBE_GROUP --cluster-name $KUBE_NAME -n gpuworker

kubectl -n kube-system describe configmap cluster-autoscaler-status

kubectl label node aks-nodepool1-36260817-vmss000000 workload=core

kubectl label node aks-scalingpool-36260817-vmss000000 workload=zeroscaler

kubectl taint node aks-gpuworker-36260817-vmss000001 expensive=true:NoSchedule


[?storageProfile.osDisk.osType=='Linux'].{Name:name,  admin:osProfile.adminUsername}" --output tabl

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)
SERVICE_PRINCIPAL_ID=$(az aks show --resource-group $KUBE_GROUP --name $KUBE_NAME --query servicePrincipalProfile.clientId -o tsv)   
SERVICE_PRINCIPAL_SECRET=$(az ad app credential reset --id $SERVICE_PRINCIPAL_ID --append --credential-description "autoscaler" -o json | jq '.password' -r)
NODE_GROUP=$(az aks show --resource-group $KUBE_GROUP --name $KUBE_NAME --query nodeResourceGroup -o tsv)
SCALE_SET_NAME=$(az vmss list --resource-group $NODE_GROUP --query [0].name -o tsv)

az role assignment create --role "Contributor" --assignee $SERVICE_PRINCIPAL_ID -g $KUBE_GROUP

B_SERVICE_PRINCIPAL_ID=$(echo $SERVICE_PRINCIPAL_ID | base64 )
B_SERVICE_PRINCIPAL_SECRET=$(echo $SERVICE_PRINCIPAL_SECRET | base64 )
B_KUBE_NAME=$(echo $KUBE_NAME | base64 )
B_KUBE_GROUP=$(echo $KUBE_GROUP | base64 )
B_NODE_GROUP=$(echo $NODE_GROUP | base64 )
B_SUBSCRIPTION_ID=$(echo $SUBSCRIPTION_ID | base64 )
B_TENANT_ID=$(echo $TENANT_ID | base64 )

helm template my-release stable/cluster-autoscaler  --set "cloudProvider=azure,autoscalingGroups[0].name=your-asg-name,autoscalingGroups[0].maxSize=10,autoscalingGroups[0].minSize=0,autoDiscovery.enabled=true"

cat <<EOF | kubectl apply -f -
apiVersion: v1
data:
  ClientID: $B_SERVICE_PRINCIPAL_ID
  ClientSecret: $B_SERVICE_PRINCIPAL_SECRET
  ResourceGroup: $B_NODE_GROUP
  SubscriptionID: $B_SUBSCRIPTION_ID
  TenantID: $B_TENANT_ID
  VMType: dm1zcw==
kind: Secret
metadata:
  name: cluster-autoscaler-azure
  namespace: kube-system
EOF

for aKS
cat <<EOF | kubectl apply -f -
apiVersion: v1
data:
  ClientID: $B_SERVICE_PRINCIPAL_ID
  ClientSecret: $B_SERVICE_PRINCIPAL_SECRET
  ResourceGroup: $B_KUBE_GROUP
  SubscriptionID: $B_SUBSCRIPTION_ID
  TenantID: $B_TENANT_ID
  VMType: QUtTCg==
  ClusterName: $B_KUBE_NAME
  NodeResourceGroup: $B_NODE_GROUP
kind: Secret
metadata:
  name: cluster-autoscaler-azure
  namespace: kube-system
EOF

kubectl get secret  cluster-autoscaler-azure -n kube-system -o yaml

kubectl delete secret  cluster-autoscaler-azure -n kube-system

kubectl apply -f bestpractices/zeroscaler.yaml         

kubectl logs -l app=cluster-autoscaler --tail 2 -n kube-system

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: centos1
spec:
  containers:
  - name: centos
    image: centos
    ports:
    - containerPort: 80
    command:
    - sleep
    - "3600"
    resources:
      limits:
        nvidia.com/gpu: 1
EOF

kubectl patch deployment dummy-logger -p \
  '{"spec":{"template":{"spec":{"tolerations":[{"key":"expensive","operator":"Equal","value":"true","effect":"NoSchedule"}]}}}}'

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: centos1
spec:
  nodeSelector:
    workload: zeroscaler
  tolerations:
  - key: "expensive"
    operator: "Equal"
    value: "true"
    effect: "NoSchedule"
  containers:
  - name: centos
    image: centos
    ports:
    - containerPort: 80
    command:
    - sleep
    - "3600"
    resources:
      limits:
        nvidia.com/gpu: 1
EOF

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: centos
spec:
  tolerations:
  - key: "expensive"
    operator: "Equal"
    value: "true"
    effect: "NoSchedule"
  containers:
  - name: centos
    image: centos
    ports:
    - containerPort: 80
    command:
    - sleep
    - "3600"
    resources:
      limits:
        nvidia.com/gpu: 1
EOF

cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  labels:
    app: samples-tf-mnist-demo
  name: samples-tf-mnist-demo
spec:
  template:
    metadata:
      labels:
        app: samples-tf-mnist-demo
    spec:
      tolerations:
      - key: "expensive"
        operator: "Equal"
        value: "true"
        effect: "NoSchedule"
      containers:
      - name: samples-tf-mnist-demo
        image: microsoft/samples-tf-mnist-demo:gpu
        args: ["--max_steps", "500"]
        imagePullPolicy: IfNotPresent
        resources:
          limits:
            nvidia.com/gpu: 1
      restartPolicy: OnFailure
EOF

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
