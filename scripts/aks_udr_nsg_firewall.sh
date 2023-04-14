#!/bin/sh

#
# wget https://raw.githubusercontent.com/denniszielke/container_demos/master/scripts/aks_lima_v2.sh
# chmod +x ./aks_udr_nsg_firewall.sh
# bash ./aks_udr_nsg_firewall.sh
#

set -e

# https://docs.microsoft.com/en-us/azure/virtual-network/virtual-networks-udr-overview#service-tags-for-user-defined-routes-preview

KUBE_GROUP="hbspoke1" # here enter the resources group name of your AKS cluster
KUBE_NAME="dzprivaks1" # here enter the name of your kubernetes resource
LOCATION="westeurope" # here enter the datacenter location
AKS_POSTFIX="-1"
NODE_GROUP=$KUBE_GROUP"_"$KUBE_NAME"_"$AKS_POSTFIX"_nodes_"$LOCATION # name of the node resource group
KUBE_VNET_NAME="knets" # here enter the name of your vnet
KUBE_FW_SUBNET_NAME="AzureFirewallSubnet" # this you cannot change
APPGW_SUBNET_NAME="gw-1-subnet"
KUBE_ING_SUBNET_NAME="ing-4-subnet" # here enter the name of your ingress subnet
KUBE_AGENT_SUBNET_NAME="aks-5-subnet" # here enter the name of your AKS subnet
POD_AGENT_SUBNET_NAME="pod-8-subnet" 
VNET_GROUP="hbhub1" # here enter the network resource group name
HUB_VNET_NAME="hubnet1" # here enter the name of your hub net
PREM_VNET_NAME="onpremnet1" # here enter the name of your onprem vnet
FW_NAME="dzkubenetfw" # here enter the name of your azure firewall resource
APPGW_NAME="dzkubeappgw"
KUBE_VERSION="$(az aks get-versions -l $LOCATION --query 'orchestrators[?default == `true`].orchestratorVersion' -o tsv)" # here enter the kubernetes version of your AKS
AAD_GROUP_ID="9329d38c-5296-4ecb-afa5-3e74f9abe09f" #"77801859-4ac2-4492-9fa4-091a7f09a8df" # "9329d38c-5296-4ecb-afa5-3e74f9abe09f" # here the AAD group that will be used to lock down AKS authentication
MY_OWN_OBJECT_ID=$(az ad signed-in-user show --query objectId --output tsv) # this will be your own aad object id
SUBSCRIPTION_ID=$(az account show --query id -o tsv) # here enter your subscription id
TENANT_ID=$(az account show --query tenantId -o tsv)

USE_PRIVATE_LINK="false" # use to deploy private master endpoint
USE_FW="true"
USE_POD_SUBNET="true"

az account set --subscription $SUBSCRIPTION_ID

echo "using Kubernetes version $KUBE_VERSION"

# az extension add --name azure-firewall
# az extension update --name azure-firewall

# az extension add --name aks-preview
# az extension update --name aks-preview

if [ $(az group exists --name $KUBE_GROUP) = false ]; then
    echo "creating resource group $KUBE_GROUP..."
    az group create -n $KUBE_GROUP -l $LOCATION -o none
    echo "resource group $KUBE_GROUP created"
else   
    echo "resource group $KUBE_GROUP already exists"
fi

if [ $(az group exists --name $VNET_GROUP) = false ]; then
    echo "creating resource group $VNET_GROUP..."
    az group create -n $VNET_GROUP -l $LOCATION -o none
    echo "resource group $VNET_GROUP created"
else   
    echo "resource group $VNET_GROUP already exists"
fi

echo "setting up k8s vnet"

VNET_RESOURCE_ID=$(az network vnet list -g $KUBE_GROUP --query "[?contains(name, '$KUBE_VNET_NAME')].id" -o tsv)
if [ "$VNET_RESOURCE_ID" == "" ]; then
    echo "creating vnet $KUBE_VNET_NAME..."
    az network vnet create -g $KUBE_GROUP -n $KUBE_VNET_NAME --address-prefixes 10.0.4.0/22 172.16.0.0/18 -o none
    az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_ING_SUBNET_NAME --address-prefix 10.0.4.0/24  -o none
    az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_AGENT_SUBNET_NAME --address-prefix 10.0.5.0/24   -o none
    az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $POD_AGENT_SUBNET_NAME --address-prefix 172.16.0.0/22   -o none
    VNET_RESOURCE_ID=$(az network vnet show -g $KUBE_GROUP -n $KUBE_VNET_NAME --query id -o tsv)
    echo "created $VNET_RESOURCE_ID"
else
    echo "vnet $VNET_RESOURCE_ID already exists"
fi

echo "setting up hub vnet"

HUBVNET_RESOURCE_ID=$(az network vnet list -g $VNET_GROUP --query "[?contains(name, '$HUB_VNET_NAME')].id" -o tsv)
if [ "$HUBVNET_RESOURCE_ID" == "" ]; then
    echo "creating vnet $HUB_VNET_NAME..."
    az network vnet create -g $VNET_GROUP -n $HUB_VNET_NAME --address-prefixes 10.0.0.0/22 -o none
    az network vnet subnet create -g $VNET_GROUP --vnet-name $HUB_VNET_NAME -n AzureFirewallSubnet --address-prefix 10.0.0.0/24 -o none
    az network vnet subnet create -g $VNET_GROUP --vnet-name $HUB_VNET_NAME -n $APPGW_SUBNET_NAME --address-prefix 10.0.1.0/24 -o none
    HUBVNET_RESOURCE_ID=$(az network vnet show -g $VNET_GROUP -n $HUB_VNET_NAME --query id -o tsv)
    az network vnet peering create -g $VNET_GROUP -n HubToSpoke1 --vnet-name $HUB_VNET_NAME --remote-vnet $VNET_RESOURCE_ID --allow-vnet-access -o none
    az network vnet peering create -g $KUBE_GROUP -n Spoke1ToHub --vnet-name $KUBE_VNET_NAME --remote-vnet $HUBVNET_RESOURCE_ID --allow-vnet-access -o none
    echo "created $HUBVNET_RESOURCE_ID"
else
    echo "vnet $HUBVNET_RESOURCE_ID already exists"
fi

echo "setting up dns zone"

if [ "$USE_PRIVATE_LINK" == "true" ]; then
    DNS_ZONE_ID=$(az network private-dns zone list -g $VNET_GROUP --query "[?contains(name, 'privatelink.$LOCATION.azmk8s.io')].id" -o tsv)
    if [ "$DNS_ZONE_ID" == "" ]; then
        az network private-dns zone create -g $VNET_GROUP -n privatelink.$LOCATION.azmk8s.io -o none
        az network private-dns link vnet create -g $VNET_GROUP -n hubzone -z privatelink.$LOCATION.azmk8s.io -v $HUBVNET_RESOURCE_ID -e true  -o none
        az network private-dns link vnet create -g $VNET_GROUP -n k8szone -z privatelink.$LOCATION.azmk8s.io -v $VNET_RESOURCE_ID -e true  -o none
        DNS_ZONE_ID=$(az network private-dns zone show -g $VNET_GROUP -n $KUBE_NAME --query id -o tsv)
        echo "created $DNS_ZONE_ID"
    else
        echo "dns zone $DNS_ZONE_ID already exists"
    fi
fi

echo "setting up azure firewall"

if [ "$USE_FW" == "true" ]; then

FW_PUBLIC_IP_ID=$(az network public-ip list -g $VNET_GROUP --query "[?contains(name, '$FW_NAME-ip')].id" -o tsv)
if [ "$FW_PUBLIC_IP_ID" == "" ]; then
    echo "creating firewall ip"
    az network public-ip create -g $VNET_GROUP -n $FW_NAME-ip --sku STANDARD -o none
    FW_PUBLIC_IP_ID=$(az network public-ip show -g $VNET_GROUP -n $FW_NAME-ip --query id -o tsv)
    FW_PUBLIC_IP=$(az network public-ip show -g $VNET_GROUP -n $FW_NAME-ip -o tsv --query ipAddress)
    echo "created ip $FW_PUBLIC_IP_ID with ip $FW_PUBLIC_IP"
else
    FW_PUBLIC_IP=$(az network public-ip show -g $VNET_GROUP -n $FW_NAME-ip -o tsv --query ipAddress)
    echo "firewall ip $FW_PUBLIC_IP_ID with ip $FW_PUBLIC_IP already exists"
fi

echo "setting up aks"
FW_ID=$(az network firewall list -g $VNET_GROUP --query "[?contains(name, '$FW_NAME')].id" -o tsv)

if [ "$FW_ID" == "" ]; then
    echo "creating firewall $FW_NAME in $VNET_GROUP"
    az network firewall create --name $FW_NAME --resource-group $VNET_GROUP --location $LOCATION -o none
    az network firewall ip-config create --firewall-name $FW_NAME --name $FW_NAME --public-ip-address $FW_NAME-ip --resource-group $VNET_GROUP --vnet-name $HUB_VNET_NAME
    FW_ID=$(az network firewall show -g $VNET_GROUP -n $FW_NAME --query id -o tsv)
    FW_PRIVATE_IP=$(az network firewall show -g $VNET_GROUP -n $FW_NAME --query "ipConfigurations[0].privateIpAddress" -o tsv)
    echo "created firewall $FW_ID"
    echo "setting up network rules"

    az network firewall network-rule create --firewall-name $FW_NAME --collection-name "time" --destination-addresses "*"  --destination-ports 123 --name "allow network" --protocols "UDP" --resource-group $VNET_GROUP --source-addresses "*" --action "Allow" --description "aks node time sync rule" --priority 101
    az network firewall network-rule create --firewall-name $FW_NAME --collection-name "dns" --destination-addresses "*"  --destination-ports 53 --name "allow network" --protocols "Any" --resource-group $VNET_GROUP --source-addresses "*" --action "Allow" --description "aks node dns rule" --priority 102
    az network firewall network-rule create --firewall-name $FW_NAME --collection-name "servicetags" --destination-addresses "AzureContainerRegistry" "AzureFrontDoor.FirstParty" "MicrosoftContainerRegistry" "AzureActiveDirectory" "AzureMonitor" --destination-ports "*" --name "allow service tags" --protocols "Any" --resource-group $VNET_GROUP --source-addresses "*" --action "Allow" --description "allow service tags" --priority 110
    az network firewall network-rule create --firewall-name $FW_NAME --collection-name "hcp" --destination-addresses "AzureCloud.$LOCATION" --destination-ports "1194" --name "allow master tags" --protocols "UDP" --resource-group $VNET_GROUP --source-addresses "*" --action "Allow" --description "allow aks link access to masters" --priority 120

    echo "setting up application rules"

    az network firewall application-rule create --firewall-name $FW_NAME --resource-group $VNET_GROUP --collection-name 'aksfwar' -n 'fqdn' --source-addresses '*' --protocols 'http=80' 'https=443' --fqdn-tags "AzureKubernetesService" --action allow --priority 101
    az network firewall application-rule create  --firewall-name $FW_NAME --collection-name "osupdates" --name "allow network" --protocols http=80 https=443 --source-addresses "*" --resource-group $VNET_GROUP --action "Allow" --target-fqdns "download.opensuse.org" "security.ubuntu.com" "packages.microsoft.com" "azure.archive.ubuntu.com" "changelogs.ubuntu.com" "snapcraft.io" "api.snapcraft.io" "motd.ubuntu.com"  --priority 102
    az network firewall application-rule create  --firewall-name $FW_NAME --collection-name "dockerhub" --name "allow network" --protocols http=80 https=443 --source-addresses "*" --resource-group $VNET_GROUP --action "Allow" --target-fqdns "*auth.docker.io" "*cloudflare.docker.io" "*cloudflare.docker.com" "*registry-1.docker.io" --priority 200
else
    echo "firewall $FW_ID already exists"
    FW_PRIVATE_IP=$(az network firewall show -g $VNET_GROUP -n $FW_NAME --query "ipConfigurations[0].privateIpAddress" -o tsv)
fi

# FIREWALL_WORKSPACE_RESOURCE_ID=$(az monitor log-analytics workspace list --resource-group $KUBE_GROUP --query "[?contains(name, '$FW_NAME-lgw')].id" -o tsv)
# if [ "$FIREWALL_WORKSPACE_RESOURCE_ID" == "" ]; then
#     echo "creating workspace $FW_NAME in $KUBE_GROUP"
#     az monitor log-analytics workspace create --resource-group $KUBE_GROUP --workspace-name $FW_NAME-lgw --location $LOCATION
# else
#     echo "workspace $FIREWALL_WORKSPACE_RESOURCE_ID alreaedy exists"
# fi

else
    echo "ignore fw"
fi

echo "setting up user defined routes for host vnet"
KUBE_AGENT_SUBNET_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$KUBE_GROUP/providers/Microsoft.Network/virtualNetworks/$KUBE_VNET_NAME/subnets/$KUBE_AGENT_SUBNET_NAME"
ROUTE_TABLE_RESOURCE_ID=$(az network route-table list --resource-group $KUBE_GROUP --query "[?contains(name, '$FW_NAME-rt')].id" -o tsv)
if [ "$ROUTE_TABLE_RESOURCE_ID" == "" ]; then
    echo "creating route table $FW_NAME-rt in $KUBE_GROUP"
    az network route-table create -g $KUBE_GROUP --name $FW_NAME-rt
    if [ "$USE_FW" == "true" ]; then
    az network route-table route create --resource-group $KUBE_GROUP --name $FW_NAME --route-table-name $FW_NAME-rt --address-prefix 0.0.0.0/0 --next-hop-type VirtualAppliance --next-hop-ip-address $FW_PRIVATE_IP
    #else
    # az network route-table route create --resource-group $KUBE_GROUP --name $FW_NAME --route-table-name $FW_NAME-rt --address-prefix 0.0.0.0/0 --next-hop-type None
    fi
    az network route-table route create --resource-group $KUBE_GROUP --name "mcr" --route-table-name $FW_NAME-rt --address-prefix MicrosoftContainerRegistry --next-hop-type Internet
    az network route-table route create --resource-group $KUBE_GROUP --name "fd" --route-table-name $FW_NAME-rt --address-prefix AzureFrontDoor.FirstParty --next-hop-type Internet
    az network route-table route create --resource-group $KUBE_GROUP --name "aad" --route-table-name $FW_NAME-rt --address-prefix AzureActiveDirectory --next-hop-type Internet
    az network route-table route create --resource-group $KUBE_GROUP --name "adf" --route-table-name $FW_NAME-rt --address-prefix AzureFrontDoor.FirstParty --next-hop-type Internet
    az network route-table route create --resource-group $KUBE_GROUP --name "arm" --route-table-name $FW_NAME-rt --address-prefix AzureResourceManager --next-hop-type Internet
    az network route-table route create --resource-group $KUBE_GROUP --name "lb" --route-table-name $FW_NAME-rt --address-prefix GatewayManager --next-hop-type Internet
    az network route-table route create --resource-group $KUBE_GROUP --name "monitor" --route-table-name $FW_NAME-rt --address-prefix AzureMonitor --next-hop-type Internet
    az network route-table route create --resource-group $KUBE_GROUP --name "azure" --route-table-name $FW_NAME-rt --address-prefix AzureCloud.$LOCATION --next-hop-type Internet
    az network vnet subnet update --route-table $FW_NAME-rt --ids $KUBE_AGENT_SUBNET_ID
    az network route-table route list --resource-group $KUBE_GROUP --route-table-name $FW_NAME-rt
else
    echo "routetable $ROUTE_TABLE_RESOURCE_ID already exists"
fi

echo "setting up user defined routes for pod vnet"
KUBE_POD_SUBNET_ID=$(az network vnet subnet show -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $POD_AGENT_SUBNET_NAME --query id -o tsv)
POD_ROUTE_TABLE_RESOURCE_ID=$(az network route-table list --resource-group $KUBE_GROUP --query "[?contains(name, '$FW_NAME-pod-rt')].id" -o tsv)
if [ "$POD_ROUTE_TABLE_RESOURCE_ID" == "" ]; then
    echo "creating route table $FW_NAME-pod-rt in $KUBE_GROUP"
    az network route-table create -g $KUBE_GROUP --name $FW_NAME-pod-rt
    if [ "$USE_FW" == "true" ]; then
    az network route-table route create --resource-group $KUBE_GROUP --name $FW_NAME --route-table-name $FW_NAME-pod-rt --address-prefix 0.0.0.0/0 --next-hop-type VirtualAppliance --next-hop-ip-address $FW_PRIVATE_IP
    # else
    # az network route-table route create --resource-group $KUBE_GROUP --name $FW_NAME --route-table-name $FW_NAME-pod-rt --address-prefix 0.0.0.0/0 --next-hop-type None
    fi
    az network route-table route create --resource-group $KUBE_GROUP --name "aad" --route-table-name $FW_NAME-pod-rt --address-prefix AzureActiveDirectory --next-hop-type Internet
    az network route-table route create --resource-group $KUBE_GROUP --name "monitor" --route-table-name $FW_NAME-pod-rt --address-prefix AzureMonitor --next-hop-type Internet
    az network route-table route create --resource-group $KUBE_GROUP --name "azure" --route-table-name $FW_NAME-pod-rt --address-prefix AzureCloud.$LOCATION --next-hop-type Internet
    az network vnet subnet update --route-table $FW_NAME-pod-rt --ids $KUBE_POD_SUBNET_ID
    az network route-table route list --resource-group $KUBE_GROUP --route-table-name $FW_NAME-pod-rt
else
    echo "routetable $POD_ROUTE_TABLE_RESOURCE_ID already exists"
fi

ROUTE_TABLE_ID=$(az network vnet subnet show -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_AGENT_SUBNET_NAME --query routeTable.id -o tsv)
KUBE_AGENT_SUBNET_ID=$(az network vnet subnet show -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_AGENT_SUBNET_NAME --query id -o tsv)
KUBE_POD_SUBNET_ID=$(az network vnet subnet show -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $POD_AGENT_SUBNET_NAME --query id -o tsv)

if [ "$ROUTE_TABLE_ID" == "" ]; then
    echo "could not find routetable on AKS subnet $KUBE_AGENT_SUBNET_ID"
else
    echo "using routetable $ROUTE_TABLE_ID with the following entries"
    ROUTE_TABLE_GROUP=$(az network route-table show --ids $ROUTE_TABLE_ID --query "[resourceGroup]" -o tsv)
    ROUTE_TABLE_NAME=$(az network route-table show --ids $ROUTE_TABLE_ID --query "[name]" -o tsv)
    echo "if this routetable does not contain a route for '0.0.0.0/0' with target VirtualAppliance or VirtualNetworkGateway then we will not need the outbound type parameter"
    az network route-table route list --resource-group $ROUTE_TABLE_GROUP --route-table-name $ROUTE_TABLE_NAME -o table
    echo "if it does not contain a '0.0.0.0/0' route then you should set the parameter IGNORE_FORCE_ROUTE=true"
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
    echo "created controller identity $AKS_CONTROLLER_RESOURCE_ID "
    echo "assigning permissions on network $KUBE_AGENT_SUBNET_ID"
    sleep 5 # wait for replication
    az role assignment create --role "Contributor" --assignee $AKS_CLIENT_ID --scope $KUBE_AGENT_SUBNET_ID -o none
    az role assignment create --role "Contributor" --assignee $AKS_CLIENT_ID --scope $KUBE_POD_SUBNET_ID -o none
    if [ "$ROUTE_TABLE_ID" == "" ]; then
        echo "no route table used"
    else
        echo "assigning permissions on routetable $ROUTE_TABLE_ID"
        az role assignment create --role "Contributor" --assignee $AKS_CLIENT_ID --scope $ROUTE_TABLE_ID -o none
    fi
    if [ "$USE_PRIVATE_LINK" == "true" ]; then
        az role assignment create --role "Contributor" --assignee $AKS_CLIENT_ID --scope $DNS_ZONE_ID -o none
        az role assignment create --role "Contributor" --assignee $AKS_CLIENT_ID --scope $VNET_RESOURCE_ID -o none
    fi
else
    echo "controller identity $AKS_CONTROLLER_RESOURCE_ID already exists"
    echo "assigning permissions on network $KUBE_AGENT_SUBNET_ID"
    az role assignment create --role "Contributor" --assignee $AKS_CLIENT_ID --scope $KUBE_AGENT_SUBNET_ID -o none
    az role assignment create --role "Contributor" --assignee $AKS_CLIENT_ID --scope $KUBE_POD_SUBNET_ID -o none
    if [ "$ROUTE_TABLE_ID" == "" ]; then
        echo "no route table used"
    else
        echo "assigning permissions on routetable $ROUTE_TABLE_ID"
        az role assignment create --role "Contributor" --assignee $AKS_CLIENT_ID --scope $ROUTE_TABLE_ID -o none
    fi
    if [ "$USE_PRIVATE_LINK" == "true" ]; then
        az role assignment create --role "Contributor" --assignee $AKS_CLIENT_ID --scope $DNS_ZONE_ID -o none
        az role assignment create --role "Contributor" --assignee $AKS_CLIENT_ID --scope $VNET_RESOURCE_ID -o none
    fi
fi

echo "setting up aks"
AKS_ID=$(az aks list -g $KUBE_GROUP --query "[?contains(name, '$KUBE_NAME$AKS_POSTFIX')].id" -o tsv)
KUBE_AGENT_SUBNET_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$KUBE_GROUP/providers/Microsoft.Network/virtualNetworks/$KUBE_VNET_NAME/subnets/$KUBE_AGENT_SUBNET_NAME"
KUBE_POD_SUBNET_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$KUBE_GROUP/providers/Microsoft.Network/virtualNetworks/$KUBE_VNET_NAME/subnets/$POD_AGENT_SUBNET_NAME"

if [ "$USE_PRIVATE_LINK" == "true" ]; then
    ACTIVATE_PRIVATE_LINK=" --enable-private-cluster --private-dns-zone $DNS_ZONE_ID --fqdn-subdomain spoke1" # --private-dns-zone none --enable-public-fqdn
else
    ACTIVATE_PRIVATE_LINK=""
    #-outbound-type userDefinedRouting
fi

if [ "$AKS_ID" == "" ]; then
    echo "creating AKS $KUBE_NAME in $KUBE_GROUP"
    echo "using host subnet $KUBE_AGENT_SUBNET_ID"
    if [ "$USE_POD_SUBNET" == "true" ]; then
        echo "using pod subnet $KUBE_POD_SUBNET_ID"
        az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME$AKS_POSTFIX --ssh-key-value ~/.ssh/id_rsa.pub  --max-pods 250 --node-count 3 --min-count 3 --max-count 5 --enable-cluster-autoscaler --node-resource-group $NODE_GROUP --load-balancer-sku standard --network-plugin azure --vnet-subnet-id $KUBE_AGENT_SUBNET_ID --pod-subnet-id $KUBE_POD_SUBNET_ID --docker-bridge-address 172.17.0.1/16 --dns-service-ip 10.2.0.10 --service-cidr 10.2.0.0/24 --kubernetes-version $KUBE_VERSION --assign-identity $AKS_CONTROLLER_RESOURCE_ID --node-osdisk-size 300 --enable-managed-identity --enable-aad --aad-admin-group-object-ids $AAD_GROUP_ID --aad-tenant-id $TENANT_ID $ACTIVATE_PRIVATE_LINK -o none
    else
        az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME$AKS_POSTFIX --ssh-key-value ~/.ssh/id_rsa.pub  --node-count 3 --min-count 3 --max-count 5 --enable-cluster-autoscaler --node-resource-group $NODE_GROUP --load-balancer-sku standard --network-plugin azure --vnet-subnet-id $KUBE_AGENT_SUBNET_ID --docker-bridge-address 172.17.0.1/16 --dns-service-ip 10.2.0.10 --service-cidr 10.2.0.0/24 --kubernetes-version $KUBE_VERSION --assign-identity $AKS_CONTROLLER_RESOURCE_ID --node-osdisk-size 300 --enable-managed-identity --enable-aad --aad-admin-group-object-ids $AAD_GROUP_ID --aad-tenant-id $TENANT_ID $ACTIVATE_PRIVATE_LINK -o none
    fi

    #az aks update --resource-group $KUBE_GROUP --name $KUBE_NAME$AKS_POSTFIX --auto-upgrade-channel rapid
    AKS_ID=$(az aks show -g $KUBE_GROUP -n $KUBE_NAME$AKS_POSTFIX --query id -o tsv)
    echo "created AKS $AKS_ID"
else
    echo "AKS $AKS_ID already exists"
fi

if [ "$USE_PRIVATE_LINK" == "true" ]; then
    echo " no credentials"
else
    az aks get-credentials -g $KUBE_GROUP -n $KUBE_NAME$AKS_POSTFIX --admin
fi
echo "setting up azure monitor"

WORKSPACE_RESOURCE_ID=$(az monitor log-analytics workspace list --resource-group $KUBE_GROUP --query "[?contains(name, '$KUBE_NAME')].id" -o tsv)
if [ "$WORKSPACE_RESOURCE_ID" == "" ]; then
    echo "creating workspace $KUBE_NAME in $KUBE_GROUP"
    az monitor log-analytics workspace create --resource-group $KUBE_GROUP --workspace-name $KUBE_NAME --location $LOCATION -o none
    WORKSPACE_RESOURCE_ID=$(az monitor log-analytics workspace show --resource-group $KUBE_GROUP --workspace-name $KUBE_NAME -o json | jq '.id' -r)
    az aks enable-addons --resource-group $KUBE_GROUP --name $KUBE_NAME$AKS_POSTFIX --addons monitoring --workspace-resource-id $WORKSPACE_RESOURCE_ID -o none
    OMS_CLIENT_ID=$(az aks show -g $KUBE_GROUP -n $KUBE_NAME --query addonProfiles.omsagent.identity.clientId -o tsv)
    az role assignment create --assignee $OMS_CLIENT_ID --scope $AKS_ID --role "Monitoring Metrics Publisher"
else
    az aks enable-addons --resource-group $KUBE_GROUP --name $KUBE_NAME$AKS_POSTFIX --addons monitoring --workspace-resource-id $WORKSPACE_RESOURCE_ID -o none
    OMS_CLIENT_ID=$(az aks show -g $KUBE_GROUP -n $KUBE_NAME --query addonProfiles.omsagent.identity.clientId -o tsv)
    az role assignment create --assignee $OMS_CLIENT_ID --scope $AKS_ID --role "Monitoring Metrics Publisher"
fi


HCP_IP=$(kubectl get endpoints -o=jsonpath='{.items[?(@.metadata.name == "kubernetes")].subsets[].addresses[].ip}')
if [ "$HCP_IP" == "" ]; then
    echo "unable to find aks hcp ip"
else
    az network route-table route create --resource-group $KUBE_GROUP --name "hcp" --route-table-name $FW_NAME-rt --address-prefix $HCP_IP/32 --next-hop-type Internet

    #az network route-table route delete --resource-group $KUBE_GROUP --name "azure" --route-table-name $FW_NAME-rt
fi

# az aks command invoke -g $KUBE_GROUP -n $KUBE_NAME$AKS_POSTFIX -c "kubectl get pods -n kube-system"


# az aks command invoke -g <resourceGroup> -n <clusterName> -c "kubectl apply -f deployment.yaml -n default" -f deployment.yaml


# az aks command invoke -g <resourceGroup> -n <clusterName> -c "kubectl apply -f deployment.yaml -n default" -f .


# az aks command invoke -g <resourceGroup> -n <clusterName> -c "helm repo add bitnami https://charts.bitnami.com/bitnami && helm repo update && helm install my-release -f values.yaml bitnami/nginx" -f values.yaml

# REGISTRY_NAME=dzprivate

# kubectl run mcr-hello-world --quiet --image=mcr.microsoft.com/azuredocs/aks-helloworld:v1 --restart=OnFailure --port=80 --env="TITLE=it works" -- echo "Hello Kubernetes"

# kubectl run mcr-nginx --quiet --image=mcr.microsoft.com/oss/nginx/nginx --restart=OnFailure -- echo "Hello Kubernetes"

# kubectl run local-nginx --quiet --image=nginx:1.13.12-alpine --restart=OnFailure -- echo "Hello Kubernetes"

# az acr import -n $REGISTRY_NAME --source docker.io/denniszielke/aci-helloworld:latest -t aci-helloworld:latest

# az acr import -n $REGISTRY_NAME --source mcr.microsoft.com/azuredocs/aks-helloworld:v1 -t aks-helloworld:v1

# az acr import -n $REGISTRY_NAME --source docker.io/denniszielke/dummy-logger:latest -t dummy-logger:latest

# az acr import -n $REGISTRY_NAME --source docker.io/centos -t centos

# az acr repository list -n $REGISTRY_NAME 


# kubectl run acr-hello-world --quiet --image=dzprivate.azurecr.io/aks-helloworld:v1 --port=80 --restart=OnFailure --env="TITLE=it works"
# kubectl run acr-hello-world --quiet --image=dzprivate.azurecr.io/aci-helloworld:latest --port=80 --restart=OnFailure
# kubectl run acr-hello-world --quiet --image=dzprivate.azurecr.io/centis --port=80 --restart=OnFailure

# kubectl expose pod acr-hello-world --port=80 --type=LoadBalancer

