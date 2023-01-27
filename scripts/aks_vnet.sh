#!/bin/sh

#
# wget https://raw.githubusercontent.com/denniszielke/container_demos/master/scripts/aks_vnet.sh
# chmod +x ./aks_vnet.sh
# bash ./aks_vnet.sh
#

set -e

DEPLOYMENT_NAME="dzciliumbyo2" # here enter unique deployment name (ideally short and with letters for global uniqueness)
USE_PRIVATE_API="false" # use to deploy private master endpoint
USE_POD_SUBNET="false"
USE_OVERLAY="false"
USE_CILIUM="--enable-cilium-dataplane"
VNET_PREFIX="0"

AAD_GROUP_ID="0644b510-7b35-41aa-a9c6-4bfc3f644c58 --enable-azure-rbac" # here the AAD group that will be used to lock down AKS authentication
LOCATION="northcentralus" # "northcentralus" "northeurope" #"southcentralus" #"eastus2euap" #"westeurope" # here enter the datacenter location can be eastus or westeurope
KUBE_GROUP=$DEPLOYMENT_NAME # here enter the resources group name of your AKS cluster
KUBE_NAME=$DEPLOYMENT_NAME # here enter the name of your kubernetes resource
NODE_GROUP=$KUBE_GROUP"_"$KUBE_NAME"_nodes_"$LOCATION # name of the node resource group
KUBE_VNET_NAME="$DEPLOYMENT_NAME-vnet"
KUBE_FW_SUBNET_NAME="AzureFirewallSubnet" # this you cannot change
BASTION_SUBNET_NAME="AzureBastionSubnet" # this you cannot change
APPGW_SUBNET_NAME="gw-1-subnet"
KUBE_ING_SUBNET_NAME="ing-4-subnet" # here enter the name of your ingress subnet
KUBE_API_SUBNET_NAME="api-0-subnet"
KUBE_AGENT_SUBNET_NAME="aks-5-subnet" # here enter the name of your AKS subnet
POD_AGENT_SUBNET_NAME="pod-8-subnet"
ACI_AGENT_SUBNET_NAME="aci-7-subnet"
VAULT_NAME=dzkv$KUBE_NAME 
SUBSCRIPTION_ID=$(az account show --query id -o tsv) # here enter your subscription id
TENANT_ID=$(az account show --query tenantId -o tsv)
KUBE_VERSION=$(az aks get-versions -l $LOCATION --query 'orchestrators[?default == `true`].orchestratorVersion' -o tsv) # here enter the kubernetes version of your AKS
KUBE_CNI_PLUGIN="none" # azure # kubenet
MY_OWN_OBJECT_ID=$(az ad signed-in-user show --query objectId --output tsv) # this will be your own aad object id
#DNS_ID=$(az network dns zone list -g appconfig -o tsv --query "[].id")
OUTBOUNDTYPE=""
#az account set --subscription $SUBSCRIPTION_ID
PROM_RESOURCE_ID="/subscriptions/$SUBSCRIPTION_ID/resourcegroups/observability/providers/microsoft.monitor/accounts/observability"
GF_WORKSPACE="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/observability/providers/Microsoft.Dashboard/grafana/gfdashboards"

az extension add --name aks-preview
az extension update --name aks-preview

echo "deploying into subscription $SUBSCRIPTION_ID"

if [ $(az group exists --name $KUBE_GROUP) = false ]; then
    echo "creating resource group $KUBE_GROUP..."
    az group create -n $KUBE_GROUP -l $LOCATION -o none
    echo "resource group $KUBE_GROUP created"
else   
    echo "resource group $KUBE_GROUP already exists"
fi


SECRET_NAME="mySecret"
VAULT_ID=$(az keyvault list -g $KUBE_GROUP --query "[?contains(name, '$VAULT_NAME')].id" -o tsv)
if [ "$VAULT_ID" == "" ]; then
    echo "creating keyvault $VAULT_NAME"
    az keyvault create -g $KUBE_GROUP -n $VAULT_NAME -l $LOCATION -o none
    az keyvault secret set -n $SECRET_NAME --vault-name $VAULT_NAME --value MySuperSecretThatIDontWantToShareWithYou! -o none
    VAULT_ID=$(az keyvault show -g $KUBE_GROUP -n $VAULT_NAME -o tsv --query id)
    echo "created keyvault $VAULT_ID"
else
    echo "keyvault $VAULT_ID already exists"
    VAULT_ID=$(az keyvault show -g $KUBE_GROUP -n $VAULT_NAME -o tsv --query name)
fi


echo "setting up vnet"

VNET_RESOURCE_ID=$(az network vnet list -g $KUBE_GROUP --query "[?contains(name, '$KUBE_VNET_NAME')].id" -o tsv)
if [ "$VNET_RESOURCE_ID" == "" ]; then
    echo "creating vnet $KUBE_VNET_NAME..."
    az network vnet create  --address-prefixes "10.$VNET_PREFIX.0.0/19"  -g $KUBE_GROUP -n $KUBE_VNET_NAME -o none
    az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $BASTION_SUBNET_NAME --address-prefix 10.$VNET_PREFIX.0.0/24  -o none 
    az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_API_SUBNET_NAME --address-prefix 10.$VNET_PREFIX.1.0/24 --delegations Microsoft.ContainerService/managedClusters  -o none
    az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_FW_SUBNET_NAME --address-prefix 10.$VNET_PREFIX.3.0/24  -o none
    az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $APPGW_SUBNET_NAME --address-prefix 10.$VNET_PREFIX.2.0/24  -o none
    az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_ING_SUBNET_NAME --address-prefix 10.$VNET_PREFIX.4.0/24 --delegations Microsoft.ServiceNetworking/trafficControllers -o none
    az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_AGENT_SUBNET_NAME --address-prefix 10.$VNET_PREFIX.5.0/24   -o none
    az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $POD_AGENT_SUBNET_NAME --address-prefix 10.$VNET_PREFIX.8.0/22   -o none
    az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $ACI_AGENT_SUBNET_NAME --address-prefix 10.$VNET_PREFIX.16.0/20   -o none
    VNET_RESOURCE_ID=$(az network vnet show -g $KUBE_GROUP -n $KUBE_VNET_NAME --query id -o tsv)
    echo "created $VNET_RESOURCE_ID"
else
    echo "vnet $VNET_RESOURCE_ID already exists"
fi

NSG_RESOURCE_ID=$(az network nsg list -g $KUBE_GROUP --query "[?contains(name, '$POD_AGENT_SUBNET_NSG')].id" -o tsv)
if [ "$NSG_RESOURCE_ID" == "" ]; then
    echo "creating nsgs..."

    az network nsg create --name $APPGW_SUBNET_NAME --resource-group $KUBE_GROUP --location $LOCATION
    APPGW_SUBNET_NSG=$(az network nsg show -g $KUBE_GROUP -n $APPGW_SUBNET_NAME --query id -o tsv)
    APPGW_SUBNET_ID=$(az network vnet subnet show -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $APPGW_SUBNET_NAME --query id -o tsv)

    az network nsg rule create --name appgwrule --nsg-name $APPGW_SUBNET_NAME --resource-group $KUBE_GROUP --priority 110 \
    --source-address-prefixes '*' --source-port-ranges '*' \
    --destination-address-prefixes '*' --destination-port-ranges '*' --access Allow --direction Inbound \
    --protocol "*" --description "Required allow rule for AppGW."

    az network vnet subnet update --resource-group $KUBE_GROUP --network-security-group $APPGW_SUBNET_NSG --ids $APPGW_SUBNET_ID
    #az lock create --name $APPGW_SUBNET_NAME --lock-type ReadOnly --resource-group $KUBE_GROUP --resource-name $APPGW_SUBNET_NAME --resource-type Microsoft.Network/networkSecurityGroups

    az network nsg create --name $KUBE_ING_SUBNET_NAME --resource-group $KUBE_GROUP --location $LOCATION

    az network nsg rule create --name appgwrule --nsg-name $KUBE_ING_SUBNET_NAME --resource-group $KUBE_GROUP --priority 110 \
    --source-address-prefixes '*' --source-port-ranges '*' \
    --destination-address-prefixes '*' --destination-port-ranges 80 443 3443 6390 --access Allow --direction Inbound \
    --protocol "*" --description "Required allow rule for APIM."

    KUBE_ING_SUBNET_NSG=$(az network nsg show -g $KUBE_GROUP -n $KUBE_ING_SUBNET_NAME --query id -o tsv)
    KUBE_ING_SUBNET_ID=$(az network vnet subnet show -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_ING_SUBNET_NAME --query id -o tsv)
    #az network vnet subnet update --resource-group $KUBE_GROUP --network-security-group $KUBE_ING_SUBNET_NSG --ids $KUBE_ING_SUBNET_ID
    #az lock create --name $KUBE_ING_SUBNET_NAME --lock-type ReadOnly --resource-group $KUBE_GROUP --resource-name $KUBE_ING_SUBNET_NAME --resource-type Microsoft.Network/networkSecurityGroups

    az network nsg create --name $KUBE_AGENT_SUBNET_NAME --resource-group $KUBE_GROUP --location $LOCATION

    az network nsg rule create --name ingress --nsg-name $KUBE_AGENT_SUBNET_NAME --resource-group $KUBE_GROUP --priority 110 \
    --source-address-prefixes '*' --source-port-ranges '*' \
    --destination-address-prefixes '*' --destination-port-ranges 80 443 --access Allow --direction Inbound \
    --protocol "*" --description "Required to allow ingress."

    KUBE_AGENT_SUBNET_NSG=$(az network nsg show -g $KUBE_GROUP -n $KUBE_AGENT_SUBNET_NAME --query id -o tsv)
    KUBE_AGENT_SUBNET_ID=$(az network vnet subnet show -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_AGENT_SUBNET_NAME --query id -o tsv)
    az network vnet subnet update --resource-group $KUBE_GROUP --network-security-group $KUBE_AGENT_SUBNET_NSG --ids $KUBE_AGENT_SUBNET_ID
    #az lock create --name $KUBE_AGENT_SUBNET_NAME --lock-type ReadOnly --resource-group $KUBE_GROUP --resource-name $KUBE_AGENT_SUBNET_NAME --resource-type Microsoft.Network/networkSecurityGroups

    az network nsg create --name $POD_AGENT_SUBNET_NAME --resource-group $KUBE_GROUP --location $LOCATION
    POD_AGENT_SUBNET_NSG=$(az network nsg show -g $KUBE_GROUP -n $POD_AGENT_SUBNET_NAME --query id -o tsv)
    POD_AGENT_SUBNET_ID=$(az network vnet subnet show -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $POD_AGENT_SUBNET_NAME --query id -o tsv)
    az network vnet subnet update --resource-group $KUBE_GROUP --network-security-group $POD_AGENT_SUBNET_NSG --ids $POD_AGENT_SUBNET_ID
    #az lock create --name $POD_AGENT_SUBNET_NAME --lock-type ReadOnly --resource-group $KUBE_GROUP --resource-name $POD_AGENT_SUBNET_NAME --resource-type Microsoft.Network/networkSecurityGroups

    echo "cread and locked nsgs "
else
    echo "nsg $NSG_RESOURCE_ID already exists"
fi

ROUTE_TABLE_ID=$(az network vnet subnet show -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_AGENT_SUBNET_NAME --query routeTable.id -o tsv)
KUBE_AGENT_SUBNET_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$KUBE_GROUP/providers/Microsoft.Network/virtualNetworks/$KUBE_VNET_NAME/subnets/$KUBE_AGENT_SUBNET_NAME"
KUBE_POD_SUBNET_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$KUBE_GROUP/providers/Microsoft.Network/virtualNetworks/$KUBE_VNET_NAME/subnets/$POD_AGENT_SUBNET_NAME"
KUBE_API_SUBNET_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$KUBE_GROUP/providers/Microsoft.Network/virtualNetworks/$KUBE_VNET_NAME/subnets/$KUBE_API_SUBNET_NAME"
KUBE_ING_SUBNET_ID=$(az network vnet subnet show -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_ING_SUBNET_NAME --query id -o tsv)

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
AKS_CONTROLLER_CLIENT_ID="$(az identity list -g $KUBE_GROUP --query "[?contains(name, '$KUBE_NAME-ctl-id')].clientId" -o tsv)"
AKS_CONTROLLER_RESOURCE_ID="$(az identity list -g $KUBE_GROUP --query "[?contains(name, '$KUBE_NAME-clt-id')].id" -o tsv)"
if [ "$AKS_CONTROLLER_RESOURCE_ID" == "" ]; then
    echo "creating controller identity $KUBE_NAME-ctl-id in $KUBE_GROUP"
    az identity create --name $KUBE_NAME-ctl-id --resource-group $KUBE_GROUP -o none
    sleep 10 # wait for replication
    AKS_CONTROLLER_CLIENT_ID="$(az identity show -g $KUBE_GROUP -n $KUBE_NAME-ctl-id --query clientId -o tsv)"
    AKS_CONTROLLER_RESOURCE_ID="$(az identity show -g $KUBE_GROUP -n $KUBE_NAME-ctl-id --query id -o tsv)"
    echo "created controller identity $AKS_CONTROLLER_RESOURCE_ID "
    echo "assigning permissions on network $KUBE_AGENT_SUBNET_ID"
    sleep 20 # wait for replication
    AKS_CONTROLLER_CLIENT_ID="$(az identity show -g $KUBE_GROUP -n $KUBE_NAME-ctl-id --query clientId -o tsv)"
    AKS_CONTROLLER_RESOURCE_ID="$(az identity show -g $KUBE_GROUP -n $KUBE_NAME-ctl-id --query id -o tsv)"
    echo "created controller identity $AKS_CONTROLLER_RESOURCE_ID "
    echo "assigning permissions on network $KUBE_AGENT_SUBNET_ID"
    sleep 20 # wait for replication
    az role assignment create --role "Network Contributor" --assignee $AKS_CONTROLLER_CLIENT_ID --scope $KUBE_AGENT_SUBNET_ID -o none
    az role assignment create --role "Network Contributor" --assignee $AKS_CONTROLLER_CLIENT_ID --scope $KUBE_API_SUBNET_ID -o none
    az role assignment create --role "Network Contributor" --assignee $AKS_CONTROLLER_CLIENT_ID --scope $KUBE_ING_SUBNET_ID -o none
    if [ "$ROUTE_TABLE_ID" == "" ]; then
        echo "no route table used"
    else
        echo "assigning permissions on routetable $ROUTE_TABLE_ID"
        az role assignment create --role "Contributor" --assignee $AKS_CONTROLLER_CLIENT_ID --scope $ROUTE_TABLE_ID -o none
    fi
else
    echo "controller identity $AKS_CONTROLLER_RESOURCE_ID already exists"
    echo "assigning permissions on network $KUBE_AGENT_SUBNET_ID"
    az role assignment create --role "Network Contributor" --assignee $AKS_CONTROLLER_CLIENT_ID --scope $KUBE_AGENT_SUBNET_ID -o none
    az role assignment create --role "Network Contributor" --assignee $AKS_CONTROLLER_CLIENT_ID --scope $KUBE_API_SUBNET_ID -o none
    az role assignment create --role "Network Contributor" --assignee $AKS_CONTROLLER_CLIENT_ID --scope $KUBE_ING_SUBNET_ID -o none
    if [ "$ROUTE_TABLE_ID" == "" ]; then
        echo "no route table used"
    else
        echo "assigning permissions on routetable $ROUTE_TABLE_ID"
        az role assignment create --role "Contributor" --assignee $AKS_CONTROLLER_CLIENT_ID --scope $ROUTE_TABLE_ID -o none
    fi
fi

echo "setting up kubelet identity"
AKS_KUBELET_CLIENT_ID="$(az identity list -g $KUBE_GROUP --query "[?contains(name, '$KUBE_NAME-kbl-id')].clientId" -o tsv)"
AKS_KUBELET_RESOURCE_ID="$(az identity list -g $KUBE_GROUP --query "[?contains(name, '$KUBE_NAME-kbl-id')].id" -o tsv)"
if [ "$AKS_KUBELET_CLIENT_ID" == "" ]; then
    echo "creating kubelet identity $KUBE_NAME-kbl-id in $KUBE_GROUP"
    az identity create --name $KUBE_NAME-kbl-id --resource-group $KUBE_GROUP -o none
    sleep 5 # wait for replication
    AKS_KUBELET_CLIENT_ID="$(az identity show -g $KUBE_GROUP -n $KUBE_NAME-kbl-id --query clientId -o tsv)"
    AKS_KUBELET_RESOURCE_ID="$(az identity show -g $KUBE_GROUP -n $KUBE_NAME-kbl-id --query id -o tsv)"
    echo "created kubelet identity $AKS_KUBELET_RESOURCE_ID "
    sleep 25 # wait for replication
    AKS_KUBELET_CLIENT_ID="$(az identity show -g $KUBE_GROUP -n $KUBE_NAME-kbl-id --query clientId -o tsv)"
    AKS_KUBELET_RESOURCE_ID="$(az identity show -g $KUBE_GROUP -n $KUBE_NAME-kbl-id --query id -o tsv)"
    echo "created kubelet identity $AKS_KUBELET_RESOURCE_ID "
    echo "assigning permissions on keyvault $VAULT_ID"
    az keyvault set-policy -n $VAULT_NAME --object-id $AKS_KUBELET_CLIENT_ID --key-permissions get --certificate-permissions get --secret-permissions get -o none
else
    echo "kubelet identity $AKS_KUBELET_RESOURCE_ID already exists"
    echo "assigning permissions on keyvault $VAULT_ID"
    az keyvault set-policy -n $VAULT_NAME --object-id $AKS_KUBELET_CLIENT_ID --key-permissions get --certificate-permissions get --secret-permissions get -o none
fi

echo "setting up aks"
AKS_ID=$(az aks list -g $KUBE_GROUP --query "[?contains(name, '$KUBE_NAME')].id" -o tsv)

if [ "$USE_PRIVATE_API" == "true" ]; then
    ACTIVATE_PRIVATE_LINK=" --enable-private-cluster --enable-apiserver-vnet-integration --apiserver-subnet-id $KUBE_API_SUBNET_ID "
else
    ACTIVATE_PRIVATE_LINK=""
fi
# enable-overlay-mode", "true
echo "setting up aks"
AKS_ID=$(az aks list -g $KUBE_GROUP --query "[?contains(name, '$KUBE_NAME')].id" -o tsv)

if [ "$AKS_ID" == "" ]; then
    echo "creating AKS $KUBE_NAME in $KUBE_GROUP"
    echo "using host subnet $KUBE_AGENT_SUBNET_ID"

    if [ "$USE_OVERLAY" == "true" ]; then
        echo "using overlay subnet $KUBE_POD_SUBNET_ID"
        az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME$AKS_POSTFIX --ssh-key-value ~/.ssh/id_rsa.pub --node-count 2 --min-count 2 --max-count 5 --enable-cluster-autoscaler --node-resource-group $NODE_GROUP --load-balancer-sku standard --vm-set-type VirtualMachineScaleSets --network-plugin azure --network-plugin-mode overlay --pod-cidr 100.64.0.0/10 --vnet-subnet-id $KUBE_AGENT_SUBNET_ID --docker-bridge-address 172.17.0.1/16 --dns-service-ip 10.2.0.10 --service-cidr 10.2.0.0/24 --kubernetes-version $KUBE_VERSION --assign-identity $AKS_CONTROLLER_RESOURCE_ID --node-osdisk-type Ephemeral --enable-managed-identity --enable-aad --aad-admin-group-object-ids $AAD_GROUP_ID --aad-tenant-id $TENANT_ID $USE_CILIUM -o none

    else
        if [ "$USE_POD_SUBNET" == "true" ]; then
            echo "using pod subnet $KUBE_POD_SUBNET_ID"
            az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME$AKS_POSTFIX --ssh-key-value ~/.ssh/id_rsa.pub --node-count 2 --min-count 2 --max-count 5 --enable-cluster-autoscaler --node-resource-group $NODE_GROUP --load-balancer-sku standard --vm-set-type VirtualMachineScaleSets --network-plugin azure --vnet-subnet-id $KUBE_AGENT_SUBNET_ID --docker-bridge-address 172.17.0.1/16 --dns-service-ip 10.2.0.10 --service-cidr 10.2.0.0/24 --kubernetes-version $KUBE_VERSION --assign-identity $AKS_CONTROLLER_RESOURCE_ID --node-osdisk-type Ephemeral --enable-managed-identity --enable-aad --aad-admin-group-object-ids $AAD_GROUP_ID --aad-tenant-id $TENANT_ID --pod-subnet-id $KUBE_POD_SUBNET_ID $ACTIVATE_PRIVATE_LINK $USE_CILIUM --node-vm-size "Standard_DS3_v2" --os-sku CBLMariner -o none
        else
            az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME$AKS_POSTFIX --ssh-key-value ~/.ssh/id_rsa.pub --node-count 3 --min-count 2 --max-count 4 --enable-cluster-autoscaler --node-resource-group $NODE_GROUP --load-balancer-sku standard --vm-set-type VirtualMachineScaleSets --network-plugin $KUBE_CNI_PLUGIN --vnet-subnet-id $KUBE_AGENT_SUBNET_ID --docker-bridge-address 172.17.0.1/16 --dns-service-ip 10.3.0.10 --service-cidr 10.3.0.0/24 --kubernetes-version $KUBE_VERSION --assign-identity $AKS_CONTROLLER_RESOURCE_ID --node-osdisk-type Ephemeral --enable-managed-identity --enable-aad --aad-admin-group-object-ids $AAD_GROUP_ID --aad-tenant-id $TENANT_ID $ACTIVATE_PRIVATE_LINK --node-vm-size "Standard_DS3_v2" --os-sku CBLMariner -o none
        fi
    fi
    sleep 10
    # az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME$AKS_POSTFIX --ssh-key-value ~/.ssh/id_rsa.pub --zones 1 2 3  --node-count 3 --node-vm-size "Standard_D2s_v3" --min-count 3 --max-count 5 --enable-cluster-autoscaler --auto-upgrade-channel patch  --node-resource-group $NODE_GROUP --load-balancer-sku standard --enable-vmss  --network-plugin azure --vnet-subnet-id $KUBE_AGENT_SUBNET_ID --docker-bridge-address 172.17.0.1/16 --dns-service-ip 10.2.0.10 --service-cidr 10.2.0.0/24 --kubernetes-version $KUBE_VERSION --assign-identity $AKS_CONTROLLER_RESOURCE_ID --assign-kubelet-identity $AKS_KUBELET_RESOURCE_ID --node-osdisk-size 300 --enable-managed-identity --enable-aad --aad-admin-group-object-ids $AAD_GROUP_ID --aad-tenant-id $TENANT_ID $ACTIVATE_PRIVATE_LINK -o none
    az aks update -n $KUBE_NAME -g $KUBE_GROUP  --enable-oidc-issuer --enable-workload-identity --yes
    #az aks enable-addons --resource-group="$KUBE_GROUP" --name="$KUBE_NAME" --addons="virtual-node" --subnet-name $ACI_AGENT_SUBNET_NAME
    
    #az aks enable-addons --resource-group="$KUBE_GROUP" --name="$KUBE_NAME" --addons="azure-keyvault-secrets-provider"
    #az aks update --resource-group="$KUBE_GROUP" --name="$KUBE_NAME" --enable-secret-rotation --yes
    #az aks update --resource-group="$KUBE_GROUP" --name="$KUBE_NAME" --syncSecret.enabled --yes
    #az aks enable-addons --resource-group="$KUBE_GROUP" --name="$KUBE_NAME" --addons="open-service-mesh"
    #az aks enable-addons --resource-group="$KUBE_GROUP" --name="$KUBE_NAME" --addons="web_application_routing" --dns-zone-resource-id $DNS_ID
    #az aks update --resource-group="$KUBE_GROUP" --name="$KUBE_NAME" --enable-keda --yes
    #az aks update --resource-group="$KUBE_GROUP" --name="$KUBE_NAME" --enable-image-cleaner --yes
    #az aks upgrade -n $KUBE_NAME -g $KUBE_GROUP --aks-custom-headers EnableCloudControllerManager=True
    
    #az aks nodepool add --scale-down-mode Deallocate --node-count 2 --name marinerpool2 --cluster-name $KUBE_NAME --resource-group $KUBE_GROUP --os-sku CBLMariner

    az aks maintenanceconfiguration add -g $KUBE_GROUP --cluster-name $KUBE_NAME --name tuesday --weekday Tuesday  --start-hour 13
    
    #az aks nodepool add  -g $KUBE_GROUP --cluster-name $KUBE_NAME --name armpool --node-count 2 --mode system --node-vm-size Standard_D4ps_v5 --pod-subnet-id $KUBE_POD_SUBNET_ID
    #az aks nodepool add  -g $KUBE_GROUP --cluster-name $KUBE_NAME --name one --node-count 1 --mode system --node-vm-size Standard_B2ms --pod-subnet-id $KUBE_POD_SUBNET_ID
    #az aks nodepool add  -g $KUBE_GROUP --cluster-name $KUBE_NAME --name mariner22 --node-count 2 --mode system --node-vm-size Standard_D2s_v3 --pod-subnet-id $KUBE_POD_SUBNET_ID --os-sku CBLMariner
    #az aks update -g $KUBE_GROUP --name $KUBE_NAME --enable-apiserver-vnet-integration --apiserver-subnet-id $KUBE_API_SUBNET_ID
    az aks update --resource-group $KUBE_GROUP --name $KUBE_NAME --auto-upgrade-channel rapid --yes
    AKS_ID=$(az aks show -g $KUBE_GROUP -n $KUBE_NAME --query id -o tsv)
    echo "created AKS $AKS_ID"
else
    echo "AKS $AKS_ID already exists"
    #az aks enable-addons --resource-group="$KUBE_GROUP" --name="$KUBE_NAME" --addons="azure-keyvault-secrets-provider"
    #az aks update --resource-group="$KUBE_GROUP" --name="$KUBE_NAME" --enable-secret-rotation --yes
    #az aks update --resource-group="$KUBE_GROUP" --name="$KUBE_NAME" --syncSecret.enabled --yes
    #az aks enable-addons --resource-group="$KUBE_GROUP" --name="$KUBE_NAME" --addons="open-service-mesh"
    #az aks enable-addons --resource-group="$KUBE_GROUP" --name="$KUBE_NAME" --addons="web_application_routing" --dns-zone-resource-id $DNS_ID
    #az aks update --resource-group="$KUBE_GROUP" --name="$KUBE_NAME" --enable-keda --yes
fi

echo "setting up azure monitor"

WORKSPACE_RESOURCE_ID=$(az monitor log-analytics workspace list --resource-group $KUBE_GROUP --query "[?contains(name, '$KUBE_NAME')].id" -o tsv)
if [ "$WORKSPACE_RESOURCE_ID" == "" ]; then
    echo "creating workspace $KUBE_NAME in $KUBE_GROUP"
    az monitor log-analytics workspace create --resource-group $KUBE_GROUP --workspace-name $KUBE_NAME --location $LOCATION -o none
    WORKSPACE_RESOURCE_ID=$(az monitor log-analytics workspace show --resource-group $KUBE_GROUP --workspace-name $KUBE_NAME -o json | jq '.id' -r)
    az aks enable-addons --resource-group $KUBE_GROUP --name $KUBE_NAME --addons monitoring --workspace-resource-id $WORKSPACE_RESOURCE_ID
    az aks update --enable-azuremonitormetrics --resource-group $KUBE_GROUP --name $KUBE_NAME --azure-monitor-workspace-resource-id $PROM_RESOURCE_ID --grafana-resource-id $GF_WORKSPACE
    OMS_CLIENT_ID=$(az aks show -g $KUBE_GROUP -n $KUBE_NAME --query addonProfiles.omsagent.identity.clientId -o tsv)
    az role assignment create --assignee $OMS_CLIENT_ID --scope $AKS_ID --role "Monitoring Metrics Publisher"
    az monitor app-insights component create --app $KUBE_NAME-ai --location $LOCATION --resource-group $KUBE_GROUP --application-type web --kind web --workspace $WORKSPACE_RESOURCE_ID
    az monitor log-analytics workspace table update --resource-group $KUBE_GROUP  --workspace-name $KUBE_NAME --name ContainerLogV2  --plan Basic
    kubectl apply -f logging/container-azm-ms-agentconfig-v2.yaml 
fi

# az aks nodepool add --node-count 1 --scale-down-mode Deallocate --node-osdisk-type Managed --max-pods 30 --mode System --name nodepool2 --cluster-name $KUBE_NAME --resource-group $KUBE_GROUP

az aks get-credentials --resource-group=$KUBE_GROUP --name=$KUBE_NAME --admin --overwrite-existing 

echo "created this AKS cluster:"

az aks show  --resource-group=$KUBE_GROUP --name=$KUBE_NAME
