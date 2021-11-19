#!/bin/sh

#
# wget https://raw.githubusercontent.com/denniszielke/container_demos/master/scripts/aks_lima_v2.sh
# chmod +x ./aks_lima_v2.sh
# bash ./aks_lima_v2.sh
#

set -e

DEPLOYMENT_NAME="dzlima9" # here enter unique deployment name (ideally short and with letters for global uniqueness)
AAD_GROUP_ID="9329d38c-5296-4ecb-afa5-3e74f9abe09f" # here the AAD group that will be used to lock down AKS authentication
LOCATION="eastus" # here enter the datacenter location can be eastus or westeurope
KUBE_GROUP=$DEPLOYMENT_NAME # here enter the resources group name of your AKS cluster
KUBE_NAME=$DEPLOYMENT_NAME # here enter the name of your kubernetes resource
NODE_GROUP=$KUBE_GROUP"_"$KUBE_NAME"_nodes_"$LOCATION # name of the node resource group
KUBE_VNET_NAME="limavnet"
KUBE_AGENT_SUBNET_NAME="aks-5-subnet" # here enter the name of your AKS subnet
SUBSCRIPTION_ID=$(az account show --query id -o tsv) # here enter your subscription id
TENANT_ID=$(az account show --query tenantId -o tsv)
KUBE_VERSION="$(az aks get-versions -l $LOCATION --query 'orchestrators[?default == `true`].orchestratorVersion' -o tsv)" # here enter the kubernetes version of your AKS
KUBE_CNI_PLUGIN="azure"
MY_OWN_OBJECT_ID=$(az ad signed-in-user show --query objectId --output tsv) # this will be your own aad object id
OUTBOUNDTYPE=""
IGNORE_FORCE_ROUTE="true" # only set to true if you have a routetable on the AKS subnet but that routetable does not contain  a route for '0.0.0.0/0' with target VirtualAppliance or VirtualNetworkGateway
USE_PRIVATE_LINK="false" # use to deploy private master endpoint
ARC_CLUSTER_NAME="${KUBE_NAME}-cluster" 
ARC_CLUSTER_GROUP="${KUBE_GROUP}-arc" 
extensionName="${KUBE_NAME}-appsvc-ext" 
customLocationName="${KUBE_NAME}-loc"
kubeEnvironmentName="${KUBE_NAME}-kubeenv" 
ASELOCATION="northcentralusstage" # or "centraluseuap"

echo 'registering providers... (only once)'

# az feature register --namespace Microsoft.Resources --name EUAPParticipation
# az provider register -n Microsoft.Resources --wait

# az feature register --namespace Microsoft.Kubernetes
# az provider register --namespace Microsoft.Kubernetes --wait

# az feature register --namespace Microsoft.KubernetesConfiguration
# az provider register --namespace Microsoft.KubernetesConfiguration --wait

# az feature register --namespace Microsoft.ExtendedLocation
# az provider register --namespace Microsoft.ExtendedLocation --wait

# az provider register --namespace Microsoft.Web --wait
#az provider register --namespace Microsoft.OperationalInsights --wait

# az provider show -n Microsoft.Web --query "resourceTypes[?resourceType=='kubeEnvironments'].locations"

#echo "this should include 'North Central US (Stage)'"

# echo 'installing extensions...'
# az extension add --upgrade -n connectedk8s
# az extension add --upgrade -n k8s-extension
# az extension add --upgrade -n customlocation
# az extension add --yes --source "https://aka.ms/appsvc/appservice_kube-latest-py2.py3-none-any.whl"

az account set --subscription $SUBSCRIPTION_ID

if [ $(az group exists --name $KUBE_GROUP) = false ]; then
    echo "creating resource group $KUBE_GROUP..."
    az group create -n $KUBE_GROUP -l $LOCATION -o none
    echo "resource group $KUBE_GROUP created"
else   
    echo "resource group $KUBE_GROUP already exists"
fi

echo "setting up vnet"

VNET_RESOURCE_ID=$(az network vnet list -g $KUBE_GROUP --query "[?contains(name, '$KUBE_VNET_NAME')].id" -o tsv)
if [ "$VNET_RESOURCE_ID" == "" ]; then
    echo "creating vnet $KUBE_VNET_NAME..."
    az network vnet create -g $KUBE_GROUP -n $KUBE_VNET_NAME -o none
    az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n "AzureFirewallSubnet" --address-prefix 10.0.3.0/24  -o none
    az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n "gw-1-subnet" --address-prefix 10.0.2.0/24  -o none
    az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n "ing-4-subnet" --address-prefix 10.0.4.0/24  -o none
    az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_AGENT_SUBNET_NAME --address-prefix 10.0.5.0/24   -o none
    VNET_RESOURCE_ID=$(az network vnet show -g $KUBE_GROUP -n $KUBE_VNET_NAME --query id -o tsv)
    echo "created $VNET_RESOURCE_ID"
else
    echo "vnet $VNET_RESOURCE_ID already exists"
fi

ROUTE_TABLE_ID=$(az network vnet subnet show -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_AGENT_SUBNET_NAME --query routeTable.id -o tsv)
KUBE_AGENT_SUBNET_ID=$(az network vnet subnet show -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_AGENT_SUBNET_NAME --query id -o tsv)

if [ "$ROUTE_TABLE_ID" == "" ]; then
    echo "could not find routetable on AKS subnet $KUBE_AGENT_SUBNET_ID"
else
    echo "using routetable $ROUTE_TABLE_ID with the following entries"
    ROUTE_TABLE_GROUP=$(az network route-table show --ids $ROUTE_TABLE_ID --query "[resourceGroup]" -o tsv)
    ROUTE_TABLE_NAME=$(az network route-table show --ids $ROUTE_TABLE_ID --query "[name]" -o tsv)
    echo "if this routetable does not contain a route for '0.0.0.0/0' with target VirtualAppliance or VirtualNetworkGateway then we will not need the outbound type parameter"
    az network route-table route list --resource-group $ROUTE_TABLE_GROUP --route-table-name $ROUTE_TABLE_NAME -o table
    echo "if it does not contain a '0.0.0.0/0' route then you should set the parameter IGNORE_FORCE_ROUTE=true"
    if [ "$IGNORE_FORCE_ROUTE" == "true" ]; then
        echo "ignoring forced tunneling route information"
        OUTBOUNDTYPE=""
    else
        echo "using forced tunneling route information"
        OUTBOUNDTYPE=" --outbound-type userDefinedRouting "
    fi
fi

echo "setting up controller identity"
AKS_CLIENT_ID="$(az identity list -g $KUBE_GROUP --query "[?contains(name, '$KUBE_NAME-id')].clientId" -o tsv)"
AKS_CONTROLLER_RESOURCE_ID="$(az identity list -g $KUBE_GROUP --query "[?contains(name, '$KUBE_NAME-id')].id" -o tsv)"
if [ "$AKS_CLIENT_ID" == "" ]; then
    echo "creating controller identity $KUBE_NAME-id in $KUBE_GROUP"
    az identity create --name $KUBE_NAME-id --resource-group $KUBE_GROUP -o none
    sleep 5 # wait for replication
    AKS_CLIENT_ID="$(az identity show -g $KUBE_GROUP -n $KUBE_NAME-id  --query clientId -o tsv)"
    sleep 5 # wait for replication
    AKS_CLIENT_ID="$(az identity show -g $KUBE_GROUP -n $KUBE_NAME-id  --query clientId -o tsv)"
    AKS_CONTROLLER_RESOURCE_ID="$(az identity show -g $KUBE_GROUP -n $KUBE_NAME-id  --query id -o tsv)"
    echo "created controller identity $AKS_CONTROLLER_RESOURCE_ID "
    echo "assigning permissions on network $KUBE_AGENT_SUBNET_ID"
    sleep 25 # wait for replication
    AKS_CLIENT_ID="$(az identity show -g $KUBE_GROUP -n $KUBE_NAME-id  --query clientId -o tsv)"
    sleep 5 # wait for replication
    AKS_CLIENT_ID="$(az identity show -g $KUBE_GROUP -n $KUBE_NAME-id  --query clientId -o tsv)"
    AKS_CONTROLLER_RESOURCE_ID="$(az identity show -g $KUBE_GROUP -n $KUBE_NAME-id  --query id -o tsv)"
    sleep 10
    echo "created controller identity $AKS_CONTROLLER_RESOURCE_ID "
    echo "assigning permissions on network $KUBE_AGENT_SUBNET_ID"
    sleep 5 # wait for replication
    az role assignment create --role "Contributor" --assignee $AKS_CLIENT_ID --scope $KUBE_AGENT_SUBNET_ID -o none
    if [ "$ROUTE_TABLE_ID" == "" ]; then
        echo "no route table used"
    else
        echo "assigning permissions on routetable $ROUTE_TABLE_ID"
        az role assignment create --role "Contributor" --assignee $AKS_CLIENT_ID --scope $ROUTE_TABLE_ID -o none
    fi
else
    echo "controller identity $AKS_CONTROLLER_RESOURCE_ID already exists"
    echo "assigning permissions on network $KUBE_AGENT_SUBNET_ID"
    az role assignment create --role "Contributor" --assignee $AKS_CLIENT_ID --scope $KUBE_AGENT_SUBNET_ID -o none
    if [ "$ROUTE_TABLE_ID" == "" ]; then
        echo "no route table used"
    else
        echo "assigning permissions on routetable $ROUTE_TABLE_ID"
        az role assignment create --role "Contributor" --assignee $AKS_CLIENT_ID --scope $ROUTE_TABLE_ID -o none
    fi
fi

echo "setting up aks"
AKS_ID=$(az aks list -g $KUBE_GROUP --query "[?contains(name, '$KUBE_NAME')].id" -o tsv)

if [ "$USE_PRIVATE_LINK" == "true" ]; then
    ACTIVATE_PRIVATE_LINK=" --enable-private-cluster "
else
    ACTIVATE_PRIVATE_LINK=""
fi

if [ "$AKS_ID" == "" ]; then
    echo "creating AKS $KUBE_NAME in $KUBE_GROUP"
    az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --ssh-key-value ~/.ssh/id_rsa.pub  --node-count 3 --min-count 3 --max-count 5 --enable-cluster-autoscaler --node-resource-group $NODE_GROUP --load-balancer-sku standard --enable-vmss  --network-plugin azure --vnet-subnet-id $KUBE_AGENT_SUBNET_ID --docker-bridge-address 172.17.0.1/16 --dns-service-ip 10.2.0.10 --service-cidr 10.2.0.0/24 --kubernetes-version $KUBE_VERSION --no-ssh-key --assign-identity $AKS_CONTROLLER_RESOURCE_ID --node-osdisk-size 300 --enable-managed-identity --enable-aad --aad-admin-group-object-ids $AAD_GROUP_ID --aad-tenant-id $TENANT_ID --uptime-sla $OUTBOUNDTYPE $ACTIVATE_PRIVATE_LINK -o none
    az aks update --resource-group $KUBE_GROUP --name $KUBE_NAME --auto-upgrade-channel rapid
    AKS_ID=$(az aks show -g $KUBE_GROUP -n $KUBE_NAME --query id -o tsv)
    echo "created AKS $AKS_ID"
else
    echo "AKS $AKS_ID already exists"
fi

echo "setting up azure monitor"

WORKSPACE_RESOURCE_ID=$(az monitor log-analytics workspace list --resource-group $KUBE_GROUP --query "[?contains(name, '$KUBE_NAME')].id" -o tsv)
if [ "$WORKSPACE_RESOURCE_ID" == "" ]; then
    echo "creating workspace $KUBE_NAME in $KUBE_GROUP"
    az monitor log-analytics workspace create --resource-group $KUBE_GROUP --workspace-name $KUBE_NAME --location $LOCATION -o none
    WORKSPACE_RESOURCE_ID=$(az monitor log-analytics workspace show --resource-group $KUBE_GROUP --workspace-name $KUBE_NAME --query id -o tsv)
    # az aks enable-addons --resource-group $KUBE_GROUP --name $KUBE_NAME --addons monitoring --workspace-resource-id $WORKSPACE_RESOURCE_ID
fi


IP_ID=$(az network public-ip list -g $NODE_GROUP --query "[?contains(name, 'limaingress')].id" -o tsv)
if [ "$IP_ID" == "" ]; then
    echo "creating ingress ip limaingress"
    az network public-ip create -g $NODE_GROUP -n limaingress --sku STANDARD
    IP_ID=$(az network public-ip show -g $NODE_GROUP -n limaingress -o tsv)
    echo "created ip $IP_ID"
    IP=$(az network public-ip show -g $NODE_GROUP -n limaingress -o tsv --query ipAddress)
else
    echo "IP $IP_ID already exists"
    IP=$(az network public-ip show -g $NODE_GROUP -n limaingress -o tsv --query ipAddress)
fi


az aks get-credentials --resource-group=$KUBE_GROUP --name=$KUBE_NAME --admin --overwrite-existing 

if [ $(az group exists --name $ARC_CLUSTER_GROUP) = false ]; then
    echo "creating resource group $ARC_CLUSTER_GROUP..."
    az group create -n $ARC_CLUSTER_GROUP -l $LOCATION -o none
    echo "resource group $ARC_CLUSTER_GROUP created"
else   
    echo "resource group $ARC_CLUSTER_GROUP already exists"
fi


ARC_CLUSTER_ID=$(az connectedk8s list --resource-group $ARC_CLUSTER_GROUP  --query "[?contains(name, '$ARC_CLUSTER_NAME')].id" -o tsv)
if [ "$ARC_CLUSTER_ID" == "" ]; then
    echo "creating arc cluster object for $ARC_CLUSTER_NAME"
    az connectedk8s connect --name $ARC_CLUSTER_NAME --resource-group $ARC_CLUSTER_GROUP --distribution aks  --infrastructure azure

    sleep 5

    ARC_CLUSTER_ID=$(az connectedk8s show --resource-group $ARC_CLUSTER_GROUP --name $ARC_CLUSTER_NAME --query id -o tsv)

    echo "created arc cluster $ARC_CLUSTER_ID"
else
    echo "arc cluster $ARC_CLUSTER_ID already exists"
fi

az resource wait --ids $ARC_CLUSTER_ID --custom "properties.connectivityStatus!='Connecting'" --api-version "2021-04-01-preview"

az k8s-configuration flux create  \
    -g $ARC_CLUSTER_GROUP -c $ARC_CLUSTER_NAME -t connectedClusters \
    -n gitops-demo --namespace gitops-demo --scope cluster \
    -u https://github.com/denniszielke/arc-k8s-demo --branch master --kustomization name=kustomization1 prune=true


sleep 5

WORKSPACE_CUSTOMER_ID=$(az monitor log-analytics workspace show --resource-group $KUBE_GROUP --workspace-name $KUBE_NAME --query customerId -o tsv)
WORKSPACE_SHARED_KEY=$(az monitor log-analytics workspace get-shared-keys --resource-group $KUBE_GROUP --workspace-name $KUBE_NAME --query primarySharedKey -o tsv)

logAnalyticsCustomerIdEnc=$(echo $WORKSPACE_CUSTOMER_ID | base64)
logAnalyticsKeyEnc=$(echo $WORKSPACE_SHARED_KEY | base64) 

sleep 10

extensionId=$(az k8s-extension list -g $ARC_CLUSTER_GROUP --cluster-name $ARC_CLUSTER_NAME --cluster-type connectedClusters  --query "[?contains(name, '$extensionName')].id" -o tsv)
if [ "$extensionId" == "" ]; then
    echo "creating arc k8s extension $extensionName"
    az k8s-extension create  -g $ARC_CLUSTER_GROUP --name $extensionName \
        --cluster-type connectedClusters -c $ARC_CLUSTER_NAME \
        --extension-type 'Microsoft.Web.Appservice' --release-train stable --auto-upgrade-minor-version true \
        --scope cluster --release-namespace $customLocationName \
        --configuration-settings "Microsoft.CustomLocation.ServiceAccount=default" \
        --configuration-settings "appsNamespace=$customLocationName" \
        --configuration-settings "clusterName=$ARC_CLUSTER_NAME" \
        --configuration-settings "loadBalancerIp=$IP" \
        --configuration-settings "keda.enabled=true" \
        --configuration-settings "buildService.storageClassName=default" \
        --configuration-settings "buildService.storageAccessMode=ReadWriteOnce" \
        --configuration-settings "customConfigMap=$customLocationName/kube-environment-config" \
        --configuration-settings "envoy.annotations.service.beta.kubernetes.io/azure-load-balancer-resource-group=$NODE_GROUP" \
        --configuration-settings "logProcessor.appLogs.destination=log-analytics" \
        --configuration-protected-settings "logProcessor.appLogs.logAnalyticsConfig.customerId=$logAnalyticsCustomerIdEnc" \
        --configuration-protected-settings "logProcessor.appLogs.logAnalyticsConfig.sharedKey=$logAnalyticsKeyEnc"

        sleep 5
        extensionId=$(az k8s-extension show -g $ARC_CLUSTER_GROUP --cluster-name $ARC_CLUSTER_NAME --cluster-type connectedClusters --name $extensionName --query id -o tsv)

        sleep 5

        echo "created arc k8s extension $extensionId"
else
    echo "arc cluster $extensionId already exists"
fi

az resource wait --ids $extensionId --custom "properties.installState!='Pending'" --api-version "2020-07-01-preview"

sleep 5

customLocationId=$(az customlocation list  -g $ARC_CLUSTER_GROUP --query "[?contains(name, '$customLocationName')].id" -o tsv)
if [ "$customLocationId" == "" ]; then
    echo "creating custom location $customLocationName"
    az customlocation create -g $ARC_CLUSTER_GROUP -n $customLocationName --host-resource-id $ARC_CLUSTER_ID --namespace $customLocationName -c $extensionId -l $LOCATION
    sleep 5
    customLocationId=$(az customlocation show  -g $ARC_CLUSTER_GROUP  --name $customLocationName --query id -o tsv)
    sleep 5
    echo "created custom location $customLocationId"
else
    echo "custom location $customLocationId already exists"
fi


kubeEnvironmentId=$(az appservice kube list -g $ARC_CLUSTER_GROUP --query "[?contains(name, '$extensionName')].id" -o tsv)
if [ "$kubeEnvironmentId" == "" ]; then
    echo "creating kube environment $customLocationName"
    az appservice kube create -g $ARC_CLUSTER_GROUP -n $extensionName --custom-location $customLocationId --static-ip $IP -l $LOCATION
    sleep 5
    kubeEnvironmentId=$(az appservice kube show -g $ARC_CLUSTER_GROUP --name $extensionName --query id -o tsv)

    echo "created kube environment $kubeEnvironmentId"
else
    echo "kube environment $kubeEnvironmentId already exists"
fi

az resource wait --ids $kubeEnvironmentId --custom "properties.provisioningState=='Succeeded'" --api-version "2021-02-01"

sleep 5

appserviceplanId=$(az appservice plan list -g $ARC_CLUSTER_GROUP --query "[?contains(name, 'kubeappsplan')].id" -o tsv)
if [ "$appserviceplanId" == "" ]; then
    echo "creating app service plan kubeappsplan"
    az appservice plan create -g $ARC_CLUSTER_GROUP -n kubeappsplan --custom-location $customLocationId --sku K1 --per-site-scaling --is-linux
    az appservice plan show -g $ARC_CLUSTER_GROUP --name kubeappsplan
    sleep 5
    appserviceplanId=$(az appservice plan show -g $ARC_CLUSTER_GROUP --name kubeappsplan --query id -o tsv)

    echo "created app service plan kubeappsplan"
else
    echo "app service plan kubeappsplan already exists"
fi

az resource wait --ids $appserviceplanId --custom "properties.provisioningState=='Succeeded'" --api-version "2021-02-01"

sleep 5

dummyappId=$(az webapp list -g $ARC_CLUSTER_GROUP --query "[?contains(name, 'dzdummylogger')].id" -o tsv)
if [ "$dummyappId" == "" ]; then
    echo "creating app dzdummylogger"
    az webapp create -g $ARC_CLUSTER_GROUP -p kubeappsplan -n dzdummylogger --deployment-container-image-name denniszielke/dummy-logger:latest 
    az webapp show -g $ARC_CLUSTER_GROUP --name dzdummylogger
    sleep 5
    dummyappId=$(az webapp show -g $ARC_CLUSTER_GROUP --name dzdummylogger --query id -o tsv)
    dummyappUrl=$(az webapp show -g $ARC_CLUSTER_GROUP --name dzdummylogger --query defaultHostName -o tsv)
    echo "created app service $dummyappId with url $dummyappUrl"
else
    dummyappUrl=$(az webapp show -g $ARC_CLUSTER_GROUP --name dzdummylogger --query defaultHostName -o tsv)
    echo "app service $dummyappId already exists with url $dummyappUrl"
fi

