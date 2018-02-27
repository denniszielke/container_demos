# Installing Grafana in AKS

0. Define variables
```
Environment Variables
SUBSCRIPTION_ID=""
KUBE_GROUP="kubs"
KUBE_NAME="dzkub8"
LOCATION="eastus"
STORAGE_ACCOUNT="dzkubestor"
STORAGE_ACCOUNT_KEY=""
STORAGE_SHARE_WRITE="k8swrite"
STORAGE_SHARE_READ="k8sread"
```

## Prerequisites
- Helm
- Storage Class and persistent storage claim

## Set up storage account

1. Create storage account
```
az storage account create --resource-group  MC_$(echo $KUBE_GROUP)_$(echo $KUBE_NAME)_$(echo $LOCATION) --name $STORAGE_ACCOUNT --location $LOCATION --sku Standard_LRS
```

2. Get Keys (optional for simple deployment with storage in the same resource group)
```
az storage account keys list --account-name $STORAGE_ACCOUNT --resource-group MC_$(echo $KUBE_GROUP)_$(echo $KUBE_NAME)_$(echo $LOCATION)
```
Assign to variable
```
STORAGE_ACCOUNT_KEY=$(az storage account keys list --account-name $STORAGE_ACCOUNT --resource-group MC_$(echo $KUBE_GROUP)_$(echo $KUBE_NAME)_$(echo $LOCATION) --query [0].value)
```

3. Replace {ACCOUNT_NAME} and {STORAGE_ACCOUNT_KEY} in sc-azure.yaml
```
sed -e "s/ACCOUNT_NAME/$STORAGE_ACCOUNT/;  s/STORAGE_ACCOUNT_KEY/$STORAGE_ACCOUNT_KEY/" sc-secret.yaml > scsecret.yaml
```

4. Deploy storage class
```
kubectl create -f sc-azure.yaml
```

## Set up azure file storage

1. Create shares
```
az storage share create --name $STORAGE_SHARE_WRITE --account-name $STORAGE_ACCOUNT 
az storage share create --name $STORAGE_SHARE_READ --account-name $STORAGE_ACCOUNT 
```

2. Replace storage account name
```
sed -e "s/ACCOUNT_NAME/$STORAGE_ACCOUNT/" sc-azure-file.yaml > scazurefile.yaml
```

kubectl exec -ti myfirstapp-86776c7859-c8kcd bash

kubectl exec myfirstapp-86776c7859-c8kcd env

## Set up azure disk storage