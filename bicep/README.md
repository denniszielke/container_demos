# Deploy Azure resources

## Create vnet and identity (optional)

This script will create a controller manager identity and a vnet with subnets, nsg
```
PROJECT_NAME="myaks2"
LOCATION="westeurope"
CONTROLLER_IDENTITY_NAME="my-controller"
bash ./create.sh $PROJECT_NAME $LOCATION $CONTROLLER_IDENTITY_NAME

```

## Deploy resources with bicep (vnet and identity must exist)

This will deploy an AKS cluster using the template and require controller manager identity, aad group and vnet to be already created

```
PROJECT_NAME="myaks3"
LOCATION="westeurope"
CONTROLLER_IDENTITY_NAME="my-controller"
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
AKS_SUBNET_RESOURCE_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$PROJECT_NAME/providers/Microsoft.Network/virtualNetworks/$PROJECT_NAME-vnet/subnets/$PROJECT_NAME-aks"
AAD_GROUP_ID="0644b510-7b35-41aa-a9c6-4bfc3f644c58"
bash ./deploy.sh $PROJECT_NAME $LOCATION $CONTROLLER_IDENTITY_NAME $AKS_SUBNET_RESOURCE_ID $AAD_GROUP_ID
```
