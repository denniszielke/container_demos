# ACS Engine

0. Variables
```
SUBSCRIPTION_ID=""
KUBE_GROUP="akskube"
KUBE_NAME="dz-aks"
LOCATION="westeurope"
SERVICE_PRINCIPAL_ID=
SERVICE_PRINCIPAL_SECRET=
YOUR_SSH_KEY=$(cat ~/.ssh/id_rsa.pub)
```

# Get aks-engine tools

Download latest release from https://github.com/Azure/acs-engine/releases/tag/v0.26.2

```
wget https://github.com/Azure/aks-engine/releases/download/v0.28.1/aks-engine-v0.28.1-darwin-amd64.tar.gz
tar -zxvf aks-engine-v0.28.1-darwin-amd64.tar.gz
cd aks-engine-v0.28.1-darwin-amd64
```

# Prepare variables

1. Download config file from https://github.com/denniszielke/container_demos/blob/master/aks-engine/acseng.json

Replace `SERVICE_PRINCIPAL_ID`, `SERVICE_PRINCIPAL_SECRET` and `YOUR_SSH_KEY` with your own values

```
sed -e "s/SERVICE_PRINCIPAL_ID/$SERVICE_PRINCIPAL_ID/ ; s/SERVICE_PRINCIPAL_SECRET/$SERVICE_PRINCIPAL_SECRET/ ; s/SUBSCRIPTION_ID/$SUBSCRIPTION_ID/ ; s/KUBE_GROUP/$KUBE_GROUP/ ; s/GROUP_ID/$GROUP_ID/" acseng.json > acseng_out.json
```

2. Replace YOUR_SSH_KEY with your ssh key

# Generate aks-engine

```
./aks-engine generate akseng_out.json
```

# Deploy cluster

1. Create the resource group
```
az group create -n $KUBE_GROUP -l $LOCATION
```

2. Create cluster
```
az group deployment create \
    --name $KUBE_NAME \
    --resource-group $KUBE_GROUP \
    --template-file "_output/$KUBE_NAME/azuredeploy.json" \
    --parameters "_output/$KUBE_NAME/azuredeploy.parameters.json"
```

# Create cluster role binding

```
export KUBECONFIG=`pwd`/_output/$KUBE_NAME/kubeconfig/kubeconfig.westeurope.json
```

# Delete everything
```
az group delete -n $KUBE_GROUP
```