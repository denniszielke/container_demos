# Terraform

0. Variables
```
AZURE_TENANT_ID=$(az account show --query tenantId -o tsv)
AZURE_SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
AZURE_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
AZURE_MYOWN_OBJECT_ID=$(az ad signed-in-user show --query objectId --output tsv)
TERRAFORM_STORAGE_NAME=
TERRAFORM_RG_NAME=terraform
LOCATION=westeurope
```

1. Create a sp for terraform

```
az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/${SUBSCRIPTION_ID}" --name "terraform_sp"
az ad sp create-for-rbac --role="Reader" --scopes="/subscriptions/${SUBSCRIPTION_ID}" --name "dz_aks_sp"
```

2. Create storage for terraform state

```
az group create -n $TERRAFORM_RG_NAME -l $LOCATION

az storage account create --resource-group $TERRAFORM_RG_NAME --name $TERRAFORM_STORAGE_NAME --location $LOCATION --sku Standard_LRS

TERRAFORM_STORAGE_KEY=$(az storage account keys list --account-name $TERRAFORM_STORAGE_NAME --resource-group $TERRAFORM_RG_NAME --query "[0].value")

az storage container create -n tfstate --account-name $TERRAFORM_STORAGE_NAME --account-key $TERRAFORM_STORAGE_KEY
```

3. run terraform
```
terraform init -backend-config="storage_account_name=$TERRAFORM_STORAGE_NAME" -backend-config="container_name=tfstate" -backend-config="access_key=$TERRAFORM_STORAGE_KEY" -backend-config="key=codelab.microsoft.tfstate" 
```
```
terraform plan -out out.plan
```
```
terraform apply out.plan
```