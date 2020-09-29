#!/usr/bin/env bash
set -o pipefail

# ./deploy.sh number1 . 1231546131 westeurope subscriptionid 1.17.7


export deploymentname="$1" # deployment name REQUIRED
export terra_path="$2" # path to terraform executable REQUIRED
export aadadmin_group_id="$3" # you need to be part of this group during deployment REQUIRED
export location="$4" # azure region OPTIONAL
export subscriptionid="$5" # subscription id OPTIONAL
export kubernetes_version="$6" # kubernetes version OPTIONAL


echo "deploymentname: $deploymentname"
echo "terra_path: $terra_path"
echo "aadadmin_group_id: $aadadmin_group_id"
echo "location: $location"
echo "subscriptionid: $subscriptionid"
echo "kubernetes_version: $kubernetes_version"

if [ "$deploymentname" == "" ]; then
echo "no deploymentname provided"
exit 0;
fi

if [ "$terra_path" == "" ]; then
echo "no terraform path provided"
exit 0;
fi

if [ "$aadadmin_group_id" == "" ]; then
echo "no aad admin group id provided"
echo $aadadmin_group_id
exit 0;
fi

if [ "$location" == "" ]; then
location="westeurope"
echo "No location provided - defaulting to $location"
fi

if [ "$subscriptionid" == "" ]; then
subscriptionid=$(az account show --query id -o tsv)
echo "No subscriptionid provided defaulting to $subscriptionid"
else
az account set --subscription $subscriptionid
fi

tenantid=$(az account show --query tenantId -o tsv)

echo "This script will create an environment for $deploymentname in $location"

TERRAFORM_STORAGE_NAME="t$deploymentname$location"
TERRAFORM_STATE_RESOURCE_GROUP_NAME="state$deploymentname$location"

echo "creating terraform state storage..."
TFGROUPEXISTS=$(az group show --name $TERRAFORM_STATE_RESOURCE_GROUP_NAME --query name -o tsv --only-show-errors)
if [ "$TFGROUPEXISTS" == $TERRAFORM_STATE_RESOURCE_GROUP_NAME ]; then 
echo "terraform storage resource group $TERRAFORM_STATE_RESOURCE_GROUP_NAME exists"
else
echo "creating terraform storage resource group $TERRAFORM_STATE_RESOURCE_GROUP_NAME..."
az group create -n $TERRAFORM_STATE_RESOURCE_GROUP_NAME -l $location --output none
fi

TFSTORAGEEXISTS=$(az storage account show -g $TERRAFORM_STATE_RESOURCE_GROUP_NAME -n $TERRAFORM_STORAGE_NAME --query name -o tsv)
if [ "$TFSTORAGEEXISTS" == $TERRAFORM_STORAGE_NAME ]; then 
echo "terraform storage account $TERRAFORM_STORAGE_NAME exists"
TERRAFORM_STORAGE_KEY=$(az storage account keys list --account-name $TERRAFORM_STORAGE_NAME --resource-group $TERRAFORM_STATE_RESOURCE_GROUP_NAME --query "[0].value" -o tsv)
else
echo "creating terraform storage account $TERRAFORM_STORAGE_NAME..."
az storage account create --resource-group $TERRAFORM_STATE_RESOURCE_GROUP_NAME --name $TERRAFORM_STORAGE_NAME --location $location --sku Standard_LRS --output none
TERRAFORM_STORAGE_KEY=$(az storage account keys list --account-name $TERRAFORM_STORAGE_NAME --resource-group $TERRAFORM_STATE_RESOURCE_GROUP_NAME --query "[0].value" -o tsv)
az storage container create -n tfstate --account-name $TERRAFORM_STORAGE_NAME --account-key $TERRAFORM_STORAGE_KEY --output none
fi

if [ "$kubernetes_version" == "" ]; then
echo "getting latest aks supporte version"
KUBERNETES_VERSION=$(az aks get-versions -l $location --query 'orchestrators[?default == `true`].orchestratorVersion' -o tsv)
echo "found AKS version $KUBERNETES_VERSION"
fi

echo "initialzing terraform state storage..."

$terra_path init -backend-config="storage_account_name=$TERRAFORM_STORAGE_NAME" -backend-config="container_name=tfstate" -backend-config="access_key=$TERRAFORM_STORAGE_KEY" -backend-config="key=codelab.microsoft.tfstate" ./

echo "planning terraform..."
$terra_path plan -out $deploymentname-out.plan -var="ad_admin_group_id=$aadadmin_group_id" -var="kubernetes_version=$KUBERNETES_VERSION" -var="resource_group_name=$deploymentname" -var="deployment_name=$deploymentname" -var="location=$location" -var="tenant_id=$tenantid" -var="subscription_id=$subscriptionid"  ./


echo "running terraform apply..."
$terra_path apply $deploymentname-out.plan

# echo "it seems there is no way to automatically assign a permission on the node group..."

# KUBELET_ID=$(az aks show -g $deploymentname -n $deploymentname --query identityProfile.kubeletidentity.clientId -o tsv)
# CONTROLLER_ID=$(az aks show -g $deploymentname -n $deploymentname --query identity.principalId -o tsv)
# CONTROLLER_ID=$(az aks show -g $deploymentname -n $deploymentname --query identity.principalId -o tsv)

# NODE_GROUP=$(az aks show --resource-group $deploymentname --name $deploymentname --query nodeResourceGroup -o tsv)

# az role assignment create --role "Managed Identity Operator" --assignee $KUBELET_ID --scope /subscriptions/$subscriptionid/resourcegroups/$NODE_GROUP
# az role assignment create --role "Managed Identity Operator" --assignee $CONTROLLER_ID --scope /subscriptions/$subscriptionid/resourcegroups/$NODE_GROUP
# az role assignment create --role "Managed Identity Operator" --assignee $CONTROLLER_ID --scope /subscriptions/$subscriptionid/resourcegroups/$NODE_GROUP