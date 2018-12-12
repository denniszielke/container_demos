#ACS Engine

0. Variables
```
SUBSCRIPTION_ID=""
KUBE_GROUP="acskubevnet"
KUBE_NAME="dzkubenet"
LOCATION="westeurope"
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

wget https://github.com/Azure/acs-engine/releases/download/v0.25.3/acs-engine-v0.25.3-darwin-amd64.tar.gz
tar -zxvf acs-engine-*-darwin-amd64.tar.gz

# Prepare variables

```
sed -e "s/AAD_APP_ID/$AAD_APP_ID/ ; s/AAD_CLIENT_ID/$AAD_CLIENT_ID/ ; s/SERVICE_PRINCIPAL_ID/$SERVICE_PRINCIPAL_ID/ ; s/SERVICE_PRINCIPAL_SECRET/$SERVICE_PRINCIPAL_SECRET/ ; s/TENANT_ID/$TENANT_ID/ ; s/ADMIN_GROUP_ID/$ADMIN_GROUP_ID/ ; s/SUBSCRIPTION_ID/$SUBSCRIPTION_ID/ ; s/KUBE_GROUP/$KUBE_GROUP/ ; s/GROUP_ID/$GROUP_ID/" acseng.json > acseng_out.json
```

# Prepare acs-engine

```
./acs-engine generate acseng_out.json
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
    --name dz-vnet-acs \
    --resource-group $KUBE_GROUP \
    --template-file "_output/dz-vnet-acs/azuredeploy.json" \
    --parameters "_output/dz-vnet-acs/azuredeploy.parameters.json"
```

# Create cluster role binding

```
export KUBECONFIG=`pwd`/_output/dz-vnet-acs/kubeconfig/kubeconfig.northeurope.json
export KUBECONFIG=`pwd`/_output/dz-vnet-acs/kubeconfig/kubeconfig.westeurope.json
export KUBECONFIG=`pwd`/_output/dz-win-1803/kubeconfig/kubeconfig.northeurope.json
export KUBECONFIG=`pwd`/_output/dz-win-1809/kubeconfig/kubeconfig.northeurope.json

# using rbac aad 
ssh -i ~/.ssh/id_rsa dennis@dz-vnet-acs.northeurope.cloudapp.azure.com \
    kubectl create clusterrolebinding aad-default-cluster-admin-binding \
        --clusterrole=cluster-admin \
        --user 'https://sts.windows.net/<tenant-id>/#<user-id>'

kubectl create clusterrolebinding aad-default-cluster-admin-binding --clusterrole=cluster-admin --user=https://sts.windows.net/$TENANT_ID/#$MY_OBJECT_ID

#using rbac without aad

ssh -i ~/.ssh/id_rsa dennis@dz-vnet-18.westeurope.cloudapp.azure.com \
    kubectl create serviceaccount dennis --namespace kube-system

ssh -i ~/.ssh/id_rsa dennis@dz-vnet-18.westeurope.cloudapp.azure.com \
    kubectl create clusterrolebinding dennis --clusterrole=cluster-admin --serviceaccount=kube-system:dennis --namespace kube-system

ssh -i ~/.ssh/id_rsa dennis@dz-vnet-18.westeurope.cloudapp.azure.com \
    kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep dennis-sa | awk '{print $1}')


TOKEN=

#Set kubectl context

kubectl config set-cluster acs-cluster --server=$KUBE_MANAGEMENT_ENDPOINT --insecure-skip-tls-verify=true

kubectl config set-credentials dennis --token=$TOKEN

kubectl config set-context acs-context --cluster=acs-cluster --user=dennis

kubectl config use-context acs-context
```

# Set up route table for kubenet routing

```
rt=$(az network route-table list -g $KUBE_GROUP | jq -r '.[].name')
rt=k8s-master-31439917-routetable
az network vnet subnet update -n k8s-subnet -g $KUBE_GROUP --vnet-name k8s-vnet-31439917  --route-table $rt
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