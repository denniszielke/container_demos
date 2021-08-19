SUBSCRIPTION_ID=$(az account show --query id -o tsv) # here enter your subscription id
TENANT_ID=$(az account show --query tenantId -o tsv)
KUBE_GROUP="arclima10" # here enter the resources group name of your AKS cluster
KUBE_NAME="arclima10" # here enter the name of your kubernetes resource
LOCATION="eastus" # here enter the datacenter location
KUBE_VNET_NAME="knets" # here enter the name of your vnet
KUBE_FW_SUBNET_NAME="AzureFirewallSubnet" # this you cannot change
APPGW_SUBNET_NAME="gw-1-subnet"
KUBE_ING_SUBNET_NAME="ing-4-subnet" # here enter the name of your ingress subnet
KUBE_AGENT_SUBNET_NAME="aks-5-subnet" # here enter the name of your AKS subnet
KUBE_VERSION="$(az aks get-versions -l $LOCATION --query 'orchestrators[?default == `true`].orchestratorVersion' -o tsv)" # here enter the kubernetes version of your AKS
KUBE_CNI_PLUGIN="azure"
EXTENSIONPATH="~/Downloads/"

echo 'registering providers...'

az feature register --namespace Microsoft.Resources --name EUAPParticipation
az provider register -n Microsoft.Resources --wait

az feature register --namespace Microsoft.Kubernetes --name previewAccess
az provider register --namespace Microsoft.Kubernetes --wait

az feature register --namespace Microsoft.KubernetesConfiguration --name extensions
az provider register --namespace Microsoft.KubernetesConfiguration --wait

az feature register --namespace Microsoft.ExtendedLocation --name CustomLocations-ppauto
az provider register --namespace Microsoft.ExtendedLocation --wait

az provider register --namespace Microsoft.Web --wait

echo 'installing extensions...'
az extension add --name aks-preview
az extension update --name aks-preview
az extension add --yes --source $EXTENSIONPATH/appservice_kube-0.1.8-py2.py3-none-any.whl
az extension add --yes --source $EXTENSIONPATH/connectedk8s-0.3.5-py2.py3-none-any.whl
az extension add --yes --source $EXTENSIONPATH/customlocation-0.1.0-py2.py3-none-any.whl
az extension add --yes --source $EXTENSIONPATH/k8s_extension-0.1.0-py2.py3-none-any.whl

az account set --subscription $SUBSCRIPTION_ID
az group create -n $KUBE_GROUP -l $LOCATION

echo "setting up service principal"

SERVICE_PRINCIPAL_ID=$(az ad sp create-for-rbac --skip-assignment --name $KUBE_NAME-sp -o json | jq -r '.appId')
SERVICE_PRINCIPAL_SECRET=$(az ad app credential reset --id $SERVICE_PRINCIPAL_ID -o json | jq '.password' -r)
sleep 5 # wait for replication
az role assignment create --role "Contributor" --assignee $SERVICE_PRINCIPAL_ID -g $KUBE_GROUP

echo "setting up vnet"
az network vnet create -g $KUBE_GROUP -n $KUBE_VNET_NAME
az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_FW_SUBNET_NAME --address-prefix 10.0.3.0/24
az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $APPGW_SUBNET_NAME --address-prefix 10.0.2.0/24
az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_ING_SUBNET_NAME --address-prefix 10.0.4.0/24
az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_AGENT_SUBNET_NAME --address-prefix 10.0.5.0/24 --service-endpoints Microsoft.Sql Microsoft.AzureCosmosDB Microsoft.KeyVault Microsoft.Storage

echo "setting up aks"

KUBE_AGENT_SUBNET_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$KUBE_GROUP/providers/Microsoft.Network/virtualNetworks/$KUBE_VNET_NAME/subnets/$KUBE_AGENT_SUBNET_NAME"

az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --node-count 2 --network-plugin $KUBE_CNI_PLUGIN --vnet-subnet-id $KUBE_AGENT_SUBNET_ID --docker-bridge-address 172.17.0.1/16 --dns-service-ip 10.2.0.10 --service-cidr 10.2.0.0/24 --client-secret $SERVICE_PRINCIPAL_SECRET --service-principal $SERVICE_PRINCIPAL_ID --kubernetes-version $KUBE_VERSION --no-ssh-key

az aks get-credentials --resource-group=$KUBE_GROUP --name=$KUBE_NAME

echo "setting up azure monitor"

az monitor log-analytics workspace create --resource-group $KUBE_GROUP --workspace-name $KUBE_NAME --location $LOCATION
WORKSPACE_ID=$(az monitor log-analytics workspace show --resource-group $KUBE_GROUP --workspace-name $KUBE_NAME -o json | jq '.id' -r)
az aks enable-addons --resource-group $KUBE_GROUP --name $KUBE_NAME --addons monitoring --workspace-resource-id $WORKSPACE_ID



echo "setting up azure arc"
az extension add --name connectedk8s
az extension add --name k8sconfiguration

az extension update --name connectedk8s
az extension update --name k8sconfiguration

export appId=$SERVICE_PRINCIPAL_ID
export password=$SERVICE_PRINCIPAL_SECRET
export tenantId=$TENANT_ID
export resourceGroup=$KUBE_GROUP
export arcClusterName=$KUBE_NAME

az connectedk8s connect --name $KUBE_NAME --resource-group $KUBE_GROUP


export clusterId="$(az resource show --resource-group $resourceGroup --name $arcClusterName --resource-type "Microsoft.Kubernetes/connectedClusters" --query id)"
export clusterId="$(echo "$clusterId" | sed -e 's/^"//' -e 's/"$//')" 

echo "setting up lima"

ASELOCATION="northcentralusstage"
az aks get-credentials -n $KUBE_NAME -g $KUBE_GROUP
NODE_GROUP=$(az aks show -g $KUBE_GROUP -n $KUBE_NAME -o tsv --query nodeResourceGroup)

az role assignment create --role "Contributor" --assignee $SERVICE_PRINCIPAL_ID -g $NODE_GROUP


az network public-ip create -g $NODE_GROUP -n limaegress --sku STANDARD
IP=$(az network public-ip show -g $NODE_GROUP -n limaegress -o tsv --query ipAddress)

AKS_ID=$(az aks show -g $KUBE_GROUP -n $KUBE_NAME -o tsv --query id)
az role assignment create --assignee abfa0a7c-a6b6-4736-8310-5855508787cd --role "Azure Kubernetes Service Cluster Admin Role" --scope $AKS_ID

az extension add --source https://k8seazurecliextensiondev.blob.core.windows.net/azure-cli-extension/appservice_kube-0.1.7-py2.py3-none-any.whl

az appservice kube create -g $KUBE_GROUP -n akse -l $ASELOCATION --aks $KUBE_NAME --static-ip $IP

az appservice plan create -g $KUBE_GROUP -n kubeappsplan --kube-environment akse --kube-sku ANY

az webapp list-runtimes --linux

az webapp create -g $KUBE_GROUP -p kubeappsplan -n nodeapp1 --runtime "NODE|12-lts"

az webapp create -g $KUBE_GROUP -p kubeappsplan -n AppName --runtime "NODE|12-lts"


az webapp create -g $KUBE_GROUP -n kubeappsplan -n nodeapp1 --runtime "NODE|12-lts"

az webapp create -g $KUBE_GROUP -n kubeappsplan -n nginx1 --deployment-container-image-name docker.io/nginx:latest

az webapp create -g $KUBE_GROUP -p kubeappsplan -n corpapp1 -i myregistry.azurecr.io/imagename:tag

az webapp create -g $KUBE_GROUP -p kubeappsplan  -n dzacihello1 --deployment-container-image-name denniszielke/aci-helloworld   

az webapp create -g $KUBE_GROUP -p kubeappsplan  -n dzacihello1 --deployment-container-image-name dzbuild.azurecr.io/aci-helloworld:latest 


az aks get-upgrades --resource-group $KUBE_GROUP --name $KUBE_NAME --output table


az aks update --resource-group $KUBE_GROUP --name $KUBE_NAME --auto-upgrade-channel rapid
