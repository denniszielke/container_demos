# Create container cluster (AKS)
https://docs.microsoft.com/en-us/azure/aks/kubernetes-walkthrough

0. Variables
```
SUBSCRIPTION_ID=""
KUBE_GROUP="security"
KUBE_NAME="slbrouter"
LOCATION="westeurope"
KUBE_VERSION="1.13.7"
REGISTRY_NAME=""
APPINSIGHTS_KEY=""

SERVICE_PRINCIPAL_ID=
SERVICE_PRINCIPAL_SECRET=
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
az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --node-count 3 --generate-ssh-keys --kubernetes-version 1.10.6

az aks create -g $KUBE_GROUP -n $KUBE_NAME --kubernetes-version $KUBE_VERSION --node-count 1 --client-secret $SERVICE_PRINCIPAL_SECRET --service-principal $SERVICE_PRINCIPAL_ID --kubernetes-version $KUBE_VERSION

az aks create -g $KUBE_GROUP -n $KUBE_NAME --kubernetes-version $KUBE_VERSION --node-count 1 --enable-cluster-autoscaler --min-count 1 --max-count 3  --client-secret $SERVICE_PRINCIPAL_SECRET --service-principal $SERVICE_PRINCIPAL_ID --kubernetes-version $KUBE_VERSION  --enable-vmss

az aks update --enable-cluster-autoscaler --min-count 1 --max-count 5 -g $KUBE_GROUP -n $KUBE_NAME
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

deploy zones
```
az group create -n $KUBE_GROUP -l $LOCATION

az group deployment create \
    --name pspzones \
    --resource-group $KUBE_GROUP \
    --template-file "arm/zones_template.json" \
    --parameters "arm/zones_parameters.json" \
    --parameters "resourceName=$KUBE_NAME" \
        "location=$LOCATION" \
        "dnsPrefix=$KUBE_NAME" \
        "servicePrincipalClientId=$SERVICE_PRINCIPAL_ID" \
        "servicePrincipalClientSecret=$SERVICE_PRINCIPAL_SECRET" \
        "kubernetesVersion=$KUBE_VERSION"
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

# Delete everything
```
az group delete -n $KUBE_GROUP
```
