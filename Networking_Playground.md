SUBSCRIPTION_ID=$(az account show --query id -o tsv) # here enter your subscription id
KUBE_GROUP="net_pg_clusters" # here enter the resources group name of your aks cluster
KUBE_NAME="cluster" # here enter the name of your kubernetes resource
LOCATION="australiaeast" # here enter the datacenter location
VNET_GROUP="net_pg_networks" # here the name of the resource group for the vnet and hub resources
KUBE1_VNET_NAME="spoke1-kubevnet" # here enter the name of your vnet
KUBE2_VNET_NAME="spoke2-kubevnet" # here enter the name of your vnet
KUBE3_VNET_NAME="spoke3-kubevnet" # here enter the name of your vnet
KUBE4_VNET_NAME="spoke4-kubevnet" # here enter the name of your vnet
KUBE_ING_SUBNET_NAME="ing-1-subnet" # here enter the name of your ingress subnet
KUBE_AGENT_SUBNET_NAME="aks-2-subnet" # here enter the name of your aks subnet
NAT_EGR_SUBNET_NAME="egr-3-subnet" # here enter the name of your egress subnet
HUB_VNET_NAME="hub1-firewalvnet"
HUB_FW_SUBNET_NAME="AzureFirewallSubnet" # this you cannot change
HUB_JUMP_SUBNET_NAME="jumpbox-subnet"
KUBE_VERSION="1.16.7" # here enter the kubernetes version of your aks
NODE_GROUP=$KUBE_GROUP"_"$KUBE_NAME"_nodes_"$LOCATION # name of the node resource group
AZURE_MYOWN_OBJECT_ID=$(az ad signed-in-user show --query objectId --output tsv)
AZURE_TENANT_ID=$(az account show --query tenantId -o tsv)
AAD_GROUP_ID="9329d38c-5296-4ecb-afa5-3e74f9abe09f"


az account set --subscription $SUBSCRIPTION_ID
echo "creating resource groups"
az group create -n $KUBE_GROUP -l $LOCATION -o table
az group create -n $VNET_GROUP -l $LOCATION -o table
echo "creating vnets"
az network vnet create -g $VNET_GROUP -n $HUB_VNET_NAME --address-prefixes 10.0.0.0/22 -o table
az network vnet create -g $VNET_GROUP -n $KUBE1_VNET_NAME --address-prefixes 10.0.4.0/22 -o table
az network vnet create -g $VNET_GROUP -n $KUBE2_VNET_NAME --address-prefixes 10.0.8.0/22 -o table
az network vnet create -g $VNET_GROUP -n $KUBE3_VNET_NAME --address-prefixes 10.0.12.0/22 -o table
az network vnet create -g $VNET_GROUP -n $KUBE4_VNET_NAME --address-prefixes 10.0.16.0/22 -o table
echo "creating subnets" 
az network vnet subnet create -g $VNET_GROUP --vnet-name $HUB_VNET_NAME -n $HUB_FW_SUBNET_NAME --address-prefix 10.0.0.0/24 -o table
az network vnet subnet create -g $VNET_GROUP --vnet-name $HUB_VNET_NAME -n $HUB_JUMP_SUBNET_NAME --address-prefix 10.0.1.0/24 -o table

az network vnet subnet create -g $VNET_GROUP --vnet-name $KUBE1_VNET_NAME -n $KUBE_ING_SUBNET_NAME --address-prefix 10.0.4.0/24 -o table
az network vnet subnet create -g $VNET_GROUP --vnet-name $KUBE1_VNET_NAME -n $KUBE_AGENT_SUBNET_NAME --address-prefix 10.0.5.0/24 -o table
az network vnet subnet create -g $VNET_GROUP --vnet-name $KUBE1_VNET_NAME -n $NAT_EGR_SUBNET_NAME --address-prefix 10.0.6.0/24 -o table

az network vnet subnet create -g $VNET_GROUP --vnet-name $KUBE2_VNET_NAME -n $KUBE_ING_SUBNET_NAME --address-prefix 10.0.8.0/24 -o table
az network vnet subnet create -g $VNET_GROUP --vnet-name $KUBE2_VNET_NAME -n $KUBE_AGENT_SUBNET_NAME --address-prefix 10.0.9.0/24 -o table
az network vnet subnet create -g $VNET_GROUP --vnet-name $KUBE2_VNET_NAME -n $NAT_EGR_SUBNET_NAME --address-prefix 10.0.10.0/24 -o table

az network vnet subnet create -g $VNET_GROUP --vnet-name $KUBE3_VNET_NAME -n $KUBE_ING_SUBNET_NAME --address-prefix 10.0.12.0/24 -o table
az network vnet subnet create -g $VNET_GROUP --vnet-name $KUBE3_VNET_NAME -n $KUBE_AGENT_SUBNET_NAME --address-prefix 10.0.13.0/24 -o table
az network vnet subnet create -g $VNET_GROUP --vnet-name $KUBE3_VNET_NAME -n $NAT_EGR_SUBNET_NAME --address-prefix 10.0.14.0/24 -o table

az network vnet subnet create -g $VNET_GROUP --vnet-name $KUBE4_VNET_NAME -n $KUBE_ING_SUBNET_NAME --address-prefix 10.0.16.0/24 -o table
az network vnet subnet create -g $VNET_GROUP --vnet-name $KUBE4_VNET_NAME -n $KUBE_AGENT_SUBNET_NAME --address-prefix 10.0.17.0/24 -o table
az network vnet subnet create -g $VNET_GROUP --vnet-name $KUBE4_VNET_NAME -n $NAT_EGR_SUBNET_NAME --address-prefix 10.0.18.0/24 -o table

az network vnet peering create -g $VNET_GROUP -n HubToSpoke1 --vnet-name $HUB_VNET_NAME --remote-vnet $KUBE1_VNET_NAME --allow-vnet-access -o table
az network vnet peering create -g $VNET_GROUP -n Spoke1ToHub --vnet-name $KUBE1_VNET_NAME --remote-vnet $HUB_VNET_NAME --allow-vnet-access -o table

az network vnet peering create -g $VNET_GROUP -n HubToSpoke2 --vnet-name $HUB_VNET_NAME --remote-vnet $KUBE2_VNET_NAME --allow-vnet-access -o table
az network vnet peering create -g $VNET_GROUP -n Spoke2ToHub --vnet-name $KUBE2_VNET_NAME --remote-vnet $HUB_VNET_NAME --allow-vnet-access -o table

az network vnet peering create -g $VNET_GROUP -n HubToSpoke3 --vnet-name $HUB_VNET_NAME --remote-vnet $KUBE3_VNET_NAME --allow-vnet-access -o table
az network vnet peering create -g $VNET_GROUP -n Spoke3ToHub --vnet-name $KUBE3_VNET_NAME --remote-vnet $HUB_VNET_NAME --allow-vnet-access -o table

az network vnet peering create -g $VNET_GROUP -n HubToSpoke4 --vnet-name $HUB_VNET_NAME --remote-vnet $KUBE4_VNET_NAME --allow-vnet-access -o table
az network vnet peering create -g $VNET_GROUP -n Spoke4ToHub --vnet-name $KUBE4_VNET_NAME --remote-vnet $HUB_VNET_NAME --allow-vnet-access -o table

KUBE1_AGENT_SUBNET_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$VNET_GROUP/providers/Microsoft.Network/virtualNetworks/$KUBE1_VNET_NAME/subnets/$KUBE_AGENT_SUBNET_NAME"

KUBE_NAME=pgcluster1
NODE_GROUP=$KUBE_GROUP"_"$KUBE_NAME"_nodes_"$LOCATION # name of the node resource group
az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --node-resource-group $NODE_GROUP --load-balancer-sku standard --enable-vmss --network-plugin kubenet --vnet-subnet-id $KUBE1_AGENT_SUBNET_ID --docker-bridge-address 172.17.0.1/16 --dns-service-ip 10.2.0.10 --service-cidr 10.2.0.0/24 --pod-cidr 10.244.0.0/16 --enable-managed-identity --kubernetes-version $KUBE_VERSION --uptime-sla --no-wait


KUBE2_AGENT_SUBNET_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$VNET_GROUP/providers/Microsoft.Network/virtualNetworks/$KUBE2_VNET_NAME/subnets/$KUBE_AGENT_SUBNET_NAME"
KUBE_NAME=pgcluster2
NODE_GROUP=$KUBE_GROUP"_"$KUBE_NAME"_nodes_"$LOCATION # name of the node resource group
az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --node-resource-group $NODE_GROUP --load-balancer-sku standard --enable-vmss --network-plugin kubenet --vnet-subnet-id $KUBE2_AGENT_SUBNET_ID --docker-bridge-address 172.17.0.1/16 --dns-service-ip 10.2.0.10 --service-cidr 10.2.0.0/24 --pod-cidr 10.244.0.0/16 --enable-managed-identity --kubernetes-version $KUBE_VERSION --uptime-sla --no-wait


KUBE3_AGENT_SUBNET_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$VNET_GROUP/providers/Microsoft.Network/virtualNetworks/$KUBE3_VNET_NAME/subnets/$KUBE_AGENT_SUBNET_NAME"
KUBE_NAME=pgcluster3
NODE_GROUP=$KUBE_GROUP"_"$KUBE_NAME"_nodes_"$LOCATION # name of the node resource group
az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --node-resource-group $NODE_GROUP --load-balancer-sku standard --enable-vmss --network-plugin kubenet --vnet-subnet-id $KUBE3_AGENT_SUBNET_ID --docker-bridge-address 172.17.0.1/16 --dns-service-ip 10.3.0.10 --service-cidr 10.3.0.0/24 --pod-cidr 10.243.0.0/16 --enable-managed-identity --kubernetes-version $KUBE_VERSION --uptime-sla --no-wait


KUBE4_AGENT_SUBNET_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$VNET_GROUP/providers/Microsoft.Network/virtualNetworks/$KUBE4_VNET_NAME/subnets/$KUBE_AGENT_SUBNET_NAME"
KUBE_NAME=pgcluster4
NODE_GROUP=$KUBE_GROUP"_"$KUBE_NAME"_nodes_"$LOCATION # name of the node resource group
az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --node-resource-group $NODE_GROUP --load-balancer-sku standard --enable-vmss --network-plugin azure --vnet-subnet-id $KUBE4_AGENT_SUBNET_ID --docker-bridge-address 172.17.0.1/16 --dns-service-ip 10.4.0.10 --service-cidr 10.4.0.0/24 --enable-managed-identity --kubernetes-version $KUBE_VERSION --uptime-sla --no-wait

az aks get-credentials --resource-group=$KUBE_GROUP --name=$KUBE_NAME

az aks list --query '[].{Name:name, ClientId:servicePrincipalProfile.clientId, MsiId:identity.principalId}' -o table

az aks get 

kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/logging/dummy-logger/svc-int-ing-logger.yaml
kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/logging/dummy-logger/depl-logger.yaml

RESOURCE_ID=/subscriptions/5abd8123-18f8-427f-a4ae-30bfb82617e5/resourceGroups/net_pg_networks/providers/Microsoft.Network/networkInterfaces/dzjumpbox527
az network nic show-effective-route-table --ids $RESOURCE_ID


VMSS_RESOURCE_ID=/subscriptions/5abd8123-18f8-427f-a4ae-30bfb82617e5/resourceGroups/net_pg_clusters_pgcluster1_nodes_australiaeast/providers/Microsoft.Compute/virtualMachineScaleSets/aks-nodepool1-15360881-vmss/virtualMachines/0/networkInterfaces/aks-nodepool1-15360881-vmss

az network nic show-effective-route-table --ids $VMSS_RESOURCE_ID