SUBSCRIPTION_ID=$(az account show --query id -o tsv) # here enter your subscription id
KUBE_GROUP="kubes_fw_knet" # here enter the resources group name of your AKS cluster
KUBE_NAME="dzkubekube" # here enter the name of your kubernetes resource
LOCATION="westeurope" # here enter the datacenter location
KUBE_VNET_NAME="knets" # here enter the name of your vnet
KUBE_FW_SUBNET_NAME="AzureFirewallSubnet" # this you cannot change
APPGW_SUBNET_NAME="gw-1-subnet"
KUBE_ING_SUBNET_NAME="ing-4-subnet" # here enter the name of your ingress subnet
KUBE_AGENT_SUBNET_NAME="aks-5-subnet" # here enter the name of your AKS subnet
FW_NAME="dzkubenetfw" # here enter the name of your azure firewall resource
APPGW_NAME="dzkubeappgw"
KUBE_VERSION="$(az aks get-versions -l $LOCATION --query 'orchestrators[?default == `true`].orchestratorVersion' -o tsv)" # here enter the kubernetes version of your AKS
KUBE_CNI_PLUGIN="azure"

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

echo "setting up azure firewall"

az extension add --name azure-firewall
az network public-ip create -g $KUBE_GROUP -n $FW_NAME-ip --sku Standard
FW_PUBLIC_IP=$(az network public-ip show -g $KUBE_GROUP -n $FW_NAME-ip --query ipAddress)
az network firewall create --name $FW_NAME --resource-group $KUBE_GROUP --location $LOCATION
az network firewall ip-config create --firewall-name $FW_NAME --name $FW_NAME --public-ip-address $FW_NAME-ip --resource-group $KUBE_GROUP --vnet-name $KUBE_VNET_NAME
FW_PRIVATE_IP=$(az network firewall show -g $KUBE_GROUP -n $FW_NAME --query "ipConfigurations[0].privateIpAddress" -o tsv)
az monitor log-analytics workspace create --resource-group $KUBE_GROUP --workspace-name $FW_NAME-lgw --location $LOCATION

echo "setting up user defined routes"

KUBE_AGENT_SUBNET_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$KUBE_GROUP/providers/Microsoft.Network/virtualNetworks/$KUBE_VNET_NAME/subnets/$KUBE_AGENT_SUBNET_NAME"
az network route-table create -g $KUBE_GROUP --name $FW_NAME-rt
az network route-table route create --resource-group $KUBE_GROUP --name $FW_NAME --route-table-name $FW_NAME-rt --address-prefix 0.0.0.0/0 --next-hop-type VirtualAppliance --next-hop-ip-address $FW_PRIVATE_IP
az network vnet subnet update --route-table $FW_NAME-rt --ids $KUBE_AGENT_SUBNET_ID
az network route-table route list --resource-group $KUBE_GROUP --route-table-name $FW_NAME-rt

echo "setting up network rules"

az network firewall network-rule create --firewall-name $FW_NAME --collection-name "time" --destination-addresses "*"  --destination-ports 123 --name "allow network" --protocols "UDP" --resource-group $KUBE_GROUP --source-addresses "*" --action "Allow" --description "aks node time sync rule" --priority 101
az network firewall network-rule create --firewall-name $FW_NAME --collection-name "dns" --destination-addresses "*"  --destination-ports 53 --name "allow network" --protocols "Any" --resource-group $KUBE_GROUP --source-addresses "*" --action "Allow" --description "aks node dns rule" --priority 102
az network firewall network-rule create --firewall-name $FW_NAME --collection-name "servicetags" --destination-addresses "AzureContainerRegistry" "MicrosoftContainerRegistry" "AzureActiveDirectory" "AzureMonitor" --destination-ports "*" --name "allow service tags" --protocols "Any" --resource-group $KUBE_GROUP --source-addresses "*" --action "Allow" --description "allow service tags" --priority 110
az network firewall network-rule create --firewall-name $FW_NAME --collection-name "hcp" --destination-addresses "AzureCloud.$LOCATION" --destination-ports "1194" --name "allow master tags" --protocols "UDP" --resource-group $KUBE_GROUP --source-addresses "*" --action "Allow" --description "allow aks link access to masters" --priority 120


echo "setting up application rules"

az network firewall application-rule create --firewall-name $FW_NAME --resource-group $KUBE_GROUP --collection-name 'aksfwar' -n 'fqdn' --source-addresses '*' --protocols 'http=80' 'https=443' --fqdn-tags "AzureKubernetesService" --action allow --priority 101
az network firewall application-rule create  --firewall-name $FW_NAME --collection-name "osupdates" --name "allow network" --protocols http=80 https=443 --source-addresses "*" --resource-group $KUBE_GROUP --action "Allow" --target-fqdns "download.opensuse.org" "security.ubuntu.com" "packages.microsoft.com" "azure.archive.ubuntu.com" "changelogs.ubuntu.com" "snapcraft.io" "api.snapcraft.io" "motd.ubuntu.com"  --priority 102
az network firewall application-rule create  --firewall-name $FW_NAME --collection-name "dockerhub" --name "allow network" --protocols http=80 https=443 --source-addresses "*" --resource-group $KUBE_GROUP --action "Allow" --target-fqdns "*auth.docker.io" "*cloudflare.docker.io" "*cloudflare.docker.com" "*registry-1.docker.io" --priority 200

echo "setting up aks"

KUBE_AGENT_SUBNET_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$KUBE_GROUP/providers/Microsoft.Network/virtualNetworks/$KUBE_VNET_NAME/subnets/$KUBE_AGENT_SUBNET_NAME"

az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --node-count 2 --network-plugin $KUBE_CNI_PLUGIN --vnet-subnet-id $KUBE_AGENT_SUBNET_ID --docker-bridge-address 172.17.0.1/16 --dns-service-ip 10.2.0.10 --service-cidr 10.2.0.0/24 --client-secret $SERVICE_PRINCIPAL_SECRET --service-principal $SERVICE_PRINCIPAL_ID --kubernetes-version $KUBE_VERSION --no-ssh-key --outbound-type userDefinedRouting

echo "setting up azure monitor"

az monitor log-analytics workspace create --resource-group $KUBE_GROUP --workspace-name $KUBE_NAME --location $LOCATION
WORKSPACE_ID=$(az monitor log-analytics workspace show --resource-group $KUBE_GROUP --workspace-name $KUBE_NAME -o json | jq '.id' -r)
az aks enable-addons --resource-group $KUBE_GROUP --name $KUBE_NAME --addons monitoring --workspace-resource-id $WORKSPACE_ID