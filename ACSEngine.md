#ACS Engine

0. Variables
```
SUBSCRIPTION_ID=""
KUBE_GROUP="kubevnet"
KUBE_NAME="dzkubenet"
LOCATION="northeurope"
KUBE_VNET_NAME="KVNET"
KUBE_AGENT_SUBNET_NAME="KVAGENTS"
KUBE_MASTER_SUBNET_NAME="KVMASTERS"
SERVICE_PRINCIPAL_ID=
SERVICE_PRINCIPAL_SECRET=
AAD_APP_ID=
AAD_CLIENT_ID=
TENANT_ID=
GROUP_ID=
MY_OBJECT_ID=
YOUR_SSH_KEY=$(cat ~/.ssh/id_rsa.pub)
```

# Prepare acs-engine

```
sed -e "s/AAD_APP_ID/$AAD_APP_ID/ ; s/AAD_CLIENT_ID/$AAD_CLIENT_ID/ ; s/SERVICE_PRINCIPAL_ID/$SERVICE_PRINCIPAL_ID/ ; s/SERVICE_PRINCIPAL_SECRET/$SERVICE_PRINCIPAL_SECRET/ ; s/TENANT_ID/$TENANT_ID/ ; s/ADMIN_GROUP_ID/$ADMIN_GROUP_ID/ ; s/SUBSCRIPTION_ID/$SUBSCRIPTION_ID/ ; s/KUBE_GROUP/$KUBE_GROUP/ ; s/GROUP_ID/$GROUP_ID/" acsengvnet.json > acsengvnet_out.json
docker pull ams0/acs-engine-light-autobuild
mkdir deployment
docker run -it --rm -v deployment:/acs -w /acs ams0/acs-engine-light-autobuild:latest /acs-engine generate acsengvnet_out.json
```

# Deploy cluster

```
az login
az account set --subscription $SUBSCRIPTION_ID

```

1. Create the resource group
```
az group create -n $KUBE_GROUP -l $LOCATION
```

2. Create VNETs
```
az network vnet create -g $KUBE_GROUP -n $KUBE_VNET_NAME --address-prefixes "172.16.0.0/16" -l $LOCATION --subnet-name $KUBE_MASTER_SUBNET_NAME --subnet-prefix "172.16.0.0/24"
```

3. Create Subnets

```
az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_MASTER_SUBNET_NAME --address-prefix 172.16.0.0/24
az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_AGENT_SUBNET_NAME --address-prefix 172.16.5.0/24
```

4. Create cluster
```
az group deployment create \
    --name dz-vnet-18 \
    --resource-group $KUBE_GROUP \
    --template-file "_output/dz-vnet-18/azuredeploy.json" \
    --parameters "_output/dz-vnet-18/azuredeploy.parameters.json"
```

# Create cluster role binding

```
export KUBECONFIG=`pwd`/_output/dz-vnet-18/kubeconfig/kubeconfig.northeurope.json
export KUBECONFIG=`pwd`/_output/dz-vnet-18/kubeconfig/kubeconfig.westeurope.json

ssh -i ~/.ssh/id_rsa dennis@dz-vnet-18.northeurope.cloudapp.azure.com \
    kubectl create clusterrolebinding aad-default-cluster-admin-binding \
        --clusterrole=cluster-admin \
        --user 'https://sts.windows.net/<tenant-id>/#<user-id>'

kubectl create clusterrolebinding aad-default-cluster-admin-binding --clusterrole=cluster-admin --user=https://sts.windows.net/$TENANT_ID/#$MY_OBJECT_ID
```

# Create internal Load Balancers
https://docs.microsoft.com/en-us/azure/aks/internal-lb

```
apiVersion: v1
kind: Service
metadata:
  name: azure-vote-front
  annotations:
    service.beta.kubernetes.io/azure-load-balancer-internal: "true"
spec:
  type: LoadBalancer
  ports:
  - port: 80
  selector:
    app: azure-vote-front
```

# Delete everything
```
az group delete -n $KUBE_GROUP
```