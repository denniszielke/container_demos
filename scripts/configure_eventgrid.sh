KUBE_NAME=$1
KUBE_GROUP=$2
USE_ADDON=$3

SUBSCRIPTION_ID=$(az account show --query id -o tsv) #subscriptionid
LOCATION=$(az group show -n $KUBE_GROUP --query location -o tsv)
NODE_GROUP=$(az aks show --resource-group $KUBE_GROUP --name $KUBE_NAME --query nodeResourceGroup -o tsv)
AKS_SUBNET_ID=$(az aks show --resource-group $KUBE_GROUP --name $KUBE_NAME --query "agentPoolProfiles[0].vnetSubnetId" -o tsv)
AKS_SUBNET_NAME="aks-5-subnet"
APPGW_SUBNET_ID=$(echo ${AKS_SUBNET_ID%$AKS_SUBNET_NAME*}gw-1-subnet)
EVENTHUB_NAME=$KUBE_NAME-evthb

az eventhubs namespace create --location $LOCATION --name $EVENTHUB_NAME -g $KUBE_GROUP
az eventhubs eventhub create --name kubehub --namespace-name $EVENTHUB_NAME -g $KUBE_GROUP

SOURCE_RESOURCE_ID=$(az aks show -g $KUBE_GROUP -n $KUBE_NAME --query id --output tsv)
ENDPOINT=$(az eventhubs eventhub show -g $KUBE_GROUP -n kubehub --namespace-name $EVENTHUB_NAME --query id --output tsv)
az eventgrid event-subscription create --name kubesubscription --source-resource-id $SOURCE_RESOURCE_ID --endpoint-type eventhub --endpoint $ENDPOINT

az eventgrid event-subscription list --source-resource-id $SOURCE_RESOURCE_ID

exit

storagename="${KUBE_NAME}evts"  
queuename="eventqueue"

az storage account create -n $storagename -g $KUBE_GROUP -l $LOCATION --sku Standard_LRS
key="$(az storage account keys list -n $storagename --query "[0].{value:value}" --output tsv)"    
az storage queue create --name $queuename --account-name $storagename --account-key $key

storageid=$(az storage account show --name $storagename --resource-group $KUBE_GROUP --query id --output tsv)
queueid="$storageid/queueservices/default/queues/$queuename"
topicid=$(az eventgrid topic show --name $topicname -g $KUBE_GROUP --query id --output tsv)

az eventgrid event-subscription create \
  --source-resource-id $SOURCE_RESOURCE_ID \
  --name mystoragequeuesubscription \
  --endpoint-type storagequeue \
  --endpoint $queueid \
  --expiration-date "2025-01-01"