#https://github.com/Azure/application-gateway-kubernetes-ingress/issues/939
#https://github.com/Azure/application-gateway-kubernetes-ingress/issues?page=2&q=is%3Aissue+is%3Aopen
#https://github.com/Azure/application-gateway-kubernetes-ingress

SUBSCRIPTION_ID=$(az account show --query id -o tsv) #subscriptionid
LOCATION="westeurope" # here enter the datacenter location
VNET_GROUP="securevnets1" # here enter the network resource group name
HUB_VNET_NAME="hubnet1" # here enter the name of your hub net
KUBE_VNET_NAME="k8snet1" # here enter the name of your k8s vnet
FW_NAME="dzk8sfw1" # name of your azure firewall resource
APPGW_NAME="dzk8sappgw1"
APPGW_GROUP="secureappgw1" # here enter the appgw resource group name
APPGW_SUBNET_NAME="gw-1-subnet" # name of AppGW subnet
KUBE_AGENT_SUBNET_NAME="aks-1-subnet" # name of your AKS subnet
KUBE_AGENT2_SUBNET_NAME="aks-2-subnet" # name of your AKS subnet
KUBE_GROUP="securek8s1" # here enter the resources group name 
KUBE_NAME="secureaks1" # here enter the name of your aks resource
KUBE_VERSION="$(az aks get-versions -l $LOCATION --query 'orchestrators[?default == `true`].orchestratorVersion' -o tsv)" # here enter the kubernetes version of your AKS
KUBE_CNI_PLUGIN="azure" # alternative is "kubenet"
#KUBE_CNI_PLUGIN="kubenet"

az account set --subscription $SUBSCRIPTION_ID

echo "setting up vnet"
az group create -n $KUBE_GROUP -l $LOCATION
az group create -n $VNET_GROUP -l $LOCATION
az group create -n $APPGW_GROUP -l $LOCATION

az network vnet create -g $VNET_GROUP -n $HUB_VNET_NAME --address-prefixes 10.0.0.0/22
az network vnet create -g $VNET_GROUP -n $KUBE_VNET_NAME --address-prefixes 10.0.4.0/22
az network vnet subnet create -g $VNET_GROUP --vnet-name $HUB_VNET_NAME -n AzureFirewallSubnet --address-prefix 10.0.0.0/24
az network vnet subnet create -g $VNET_GROUP --vnet-name $HUB_VNET_NAME -n bastionsubnet --address-prefix 10.0.1.0/24
az network vnet subnet create -g $VNET_GROUP --vnet-name $KUBE_VNET_NAME -n $APPGW_SUBNET_NAME --address-prefix 10.0.4.0/24
az network vnet subnet create -g $VNET_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_AGENT_SUBNET_NAME --address-prefix 10.0.5.0/24 --service-endpoints Microsoft.Sql Microsoft.AzureCosmosDB Microsoft.KeyVault Microsoft.Storage
az network vnet subnet create -g $VNET_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_AGENT2_SUBNET_NAME --address-prefix 10.0.6.0/24 --service-endpoints Microsoft.Sql Microsoft.AzureCosmosDB Microsoft.KeyVault Microsoft.Storage
az network vnet peering create -g $VNET_GROUP -n HubToSpoke1 --vnet-name $HUB_VNET_NAME --remote-vnet $KUBE_VNET_NAME --allow-vnet-access
az network vnet peering create -g $VNET_GROUP -n Spoke1ToHub --vnet-name $KUBE_VNET_NAME --remote-vnet $HUB_VNET_NAME --allow-vnet-access

echo "setting up azure firewall"

az extension add --name azure-firewall
az network public-ip create -g $VNET_GROUP -n $FW_NAME-ip --sku Standard
FW_PUBLIC_IP=$(az network public-ip show -g $VNET_GROUP -n $FW_NAME-ip --query ipAddress)
az network firewall create --name $FW_NAME --resource-group $VNET_GROUP --location $LOCATION
az network firewall ip-config create --firewall-name $FW_NAME --name $FW_NAME --public-ip-address $FW_NAME-ip --resource-group $VNET_GROUP --vnet-name $HUB_VNET_NAME
FW_PRIVATE_IP=$(az network firewall show -g $VNET_GROUP -n $FW_NAME --query "ipConfigurations[0].privateIpAddress" -o tsv)
az monitor log-analytics workspace create --resource-group $VNET_GROUP --workspace-name $FW_NAME-lagw --location $LOCATION

echo "setting up user defined routes"

KUBE_AGENT_SUBNET_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$VNET_GROUP/providers/Microsoft.Network/virtualNetworks/$KUBE_VNET_NAME/subnets/$KUBE_AGENT_SUBNET_NAME"
az network route-table create -g $VNET_GROUP --name $KUBE_NAME-rt
az network route-table route create --resource-group $VNET_GROUP --name $FW_NAME --route-table-name $KUBE_NAME-rt --address-prefix 0.0.0.0/0 --next-hop-type VirtualAppliance --next-hop-ip-address $FW_PRIVATE_IP
az network vnet subnet update --route-table $KUBE_NAME-rt --ids $KUBE_AGENT_SUBNET_ID
az network route-table route list --resource-group $VNET_GROUP --route-table-name $KUBE_NAME-rt

echo "setting up network rules"

az network firewall network-rule create --firewall-name $FW_NAME --resource-group $VNET_GROUP --collection-name "time" --destination-addresses "*"  --destination-ports 123 --name "allow network" --protocols "UDP" --source-addresses "*" --action "Allow" --description "aks node time sync rule" --priority 101
az network firewall network-rule create --firewall-name $FW_NAME --resource-group $VNET_GROUP --collection-name "dns" --destination-addresses "*"  --destination-ports 53 --name "allow network" --protocols "Any" --source-addresses "*" --action "Allow" --description "aks node dns rule" --priority 102
az network firewall network-rule create --firewall-name $FW_NAME --resource-group $VNET_GROUP --collection-name "servicetags" --destination-addresses "AzureContainerRegistry" "MicrosoftContainerRegistry" "AzureActiveDirectory" "AzureMonitor" --destination-ports "*" --name "allow service tags" --protocols "Any" --source-addresses "*" --action "Allow" --description "allow service tags" --priority 110
az network firewall network-rule create --firewall-name $FW_NAME --resource-group $VNET_GROUP --collection-name "hcp" --destination-addresses "AzureCloud.$LOCATION" --destination-ports "1194" --name "allow master tags" --protocols "UDP" --source-addresses "*" --action "Allow" --description "allow aks link access to masters" --priority 120


echo "setting up application rules"

az network firewall application-rule create --firewall-name $FW_NAME --resource-group $VNET_GROUP --collection-name 'aksfwar' -n 'fqdn' --source-addresses '*' --protocols 'http=80' 'https=443' --fqdn-tags "AzureKubernetesService" --action allow --priority 101
az network firewall application-rule create  --firewall-name $FW_NAME --resource-group $VNET_GROUP --collection-name "osupdates" --name "allow network" --protocols http=80 https=443 --source-addresses "*"  --action "Allow" --target-fqdns "download.opensuse.org" "security.ubuntu.com" "packages.microsoft.com" "azure.archive.ubuntu.com" "changelogs.ubuntu.com" "snapcraft.io" "api.snapcraft.io" "motd.ubuntu.com"  --priority 102
az network firewall application-rule create  --firewall-name $FW_NAME --resource-group $VNET_GROUP --collection-name "dockerhub" --name "allow network" --protocols http=80 https=443 --source-addresses "*"  --action "Allow" --target-fqdns "*auth.docker.io" "*cloudflare.docker.io" "*cloudflare.docker.com" "*registry-1.docker.io" --priority 200

echo "setting up aks"

KUBE_AGENT_SUBNET_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$VNET_GROUP/providers/Microsoft.Network/virtualNetworks/$KUBE_VNET_NAME/subnets/$KUBE_AGENT_SUBNET_NAME"
KUBE_VNET_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$VNET_GROUP/providers/Microsoft.Network/virtualNetworks/$KUBE_VNET_NAME"

if [ "$KUBE_CNI_PLUGIN" == "azure" ]; then
az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --node-resource-group $KUBE_GROUP"_"$KUBE_NAME"_nodes_"$LOCATION --node-count 2 --network-plugin $KUBE_CNI_PLUGIN --vnet-subnet-id $KUBE_AGENT_SUBNET_ID --docker-bridge-address 172.17.0.1/16 --dns-service-ip 10.2.0.10 --service-cidr 10.2.0.0/24 --kubernetes-version $KUBE_VERSION --no-ssh-key --enable-managed-identity --outbound-type userDefinedRouting

CONTROLLER_ID=$(az aks show -g $KUBE_GROUP -n $KUBE_NAME --query identity.principalId -o tsv)
az role assignment create --role "Virtual Machine Contributor" --assignee $CONTROLLER_ID --scope $KUBE_VNET_ID
fi

if [ "$KUBE_CNI_PLUGIN" == "kubenet" ]; then
#az feature register --name UserAssignedIdentityPreview --namespace Microsoft.ContainerService

#sleep 200 # this might take a while
#az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/UserAssignedIdentityPreview')].{Name:name,State:properties.state}"
#sleep 200 # this might take a while
#az provider register --namespace Microsoft.ContainerService

#az identity create --name $KUBE_NAME-id --resource-group $KUBE_GROUP
#AKS_CLIENT_ID="$(az identity show -g $KUBE_GROUP -n $KUBE_NAME-id  --query clientId -o tsv)"
#AKS_CONTROLLER_RESOURCE_ID="$(az identity show -g $KUBE_GROUP -n $KUBE_NAME-id  --query id -o tsv)"

SERVICE_PRINCIPAL_ID=$(az ad sp create-for-rbac --skip-assignment --name $KUBE_NAME -o json | jq -r '.appId')
echo $SERVICE_PRINCIPAL_ID

SERVICE_PRINCIPAL_SECRET=$(az ad app credential reset --id $SERVICE_PRINCIPAL_ID -o json | jq '.password' -r)
echo $SERVICE_PRINCIPAL_SECRET

ROUTETABLE_ID=$(az network route-table show -g $VNET_GROUP --name $KUBE_NAME-rt --query id -o tsv)

#az role assignment create --role "Contributor" --assignee $AKS_CLIENT_ID --scope $KUBE_VNET_ID
az role assignment create --role "Virtual Machine Contributor" --assignee $SERVICE_PRINCIPAL_ID --scope $KUBE_VNET_ID
az role assignment create --role "Contributor" --assignee $SERVICE_PRINCIPAL_ID --scope $ROUTETABLE_ID

az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --node-resource-group $KUBE_GROUP"_"$KUBE_NAME"_nodes_"$LOCATION --node-count 2 --network-plugin $KUBE_CNI_PLUGIN --vnet-subnet-id $KUBE_AGENT_SUBNET_ID --docker-bridge-address 172.17.0.1/16 --dns-service-ip 10.2.0.10 --service-cidr 10.2.0.0/24 --kubernetes-version $KUBE_VERSION --no-ssh-key --client-secret $SERVICE_PRINCIPAL_SECRET --service-principal $SERVICE_PRINCIPAL_ID --outbound-type userDefinedRouting

fi

az aks get-credentials -g $KUBE_GROUP -n $KUBE_NAME

echo "setting up azure monitor"

az monitor log-analytics workspace create --resource-group $KUBE_GROUP --workspace-name $KUBE_NAME --location $LOCATION
WORKSPACE_ID=$(az monitor log-analytics workspace show --resource-group $KUBE_GROUP --workspace-name $KUBE_NAME -o json | jq '.id' -r)
az aks enable-addons --resource-group $KUBE_GROUP --name $KUBE_NAME --addons monitoring --workspace-resource-id $WORKSPACE_ID

echo "creating appgw"

APPGW_SUBNET_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$VNET_GROUP/providers/Microsoft.Network/virtualNetworks/$KUBE_VNET_NAME/subnets/$APPGW_SUBNET_NAME"
az network public-ip create --resource-group $APPGW_GROUP --name $APPGW_NAME-pip --allocation-method Static --sku Standard
APPGW_PUBLIC_IP=$(az network public-ip show -g $APPGW_GROUP -n $APPGW_NAME-pip --query ipAddress -o tsv)
az network application-gateway create --name $APPGW_NAME --resource-group $APPGW_GROUP --location $LOCATION --http2 Enabled --min-capacity 0 --max-capacity 10 --sku WAF_v2  --vnet-name $KUBE_VNET_NAME --subnet $APPGW_SUBNET_ID --http-settings-cookie-based-affinity Disabled --frontend-port 80 --http-settings-port 80 --http-settings-protocol Http --public-ip-address $APPGW_NAME-pip
APPGW_NAME=$(az network application-gateway list --resource-group=$APPGW_GROUP -o json | jq -r ".[0].name")
APPGW_RESOURCE_ID=$(az network application-gateway list --resource-group=$APPGW_GROUP -o json | jq -r ".[0].id")
APPGW_SUBNET_ID=$(az network application-gateway list --resource-group=$APPGW_GROUP -o json | jq -r ".[0].gatewayIpConfigurations[0].subnet.id")

az aks get-credentials -g $KUBE_GROUP -n $KUBE_NAME

echo "install aa pod identity"

if [ "$KUBE_CNI_PLUGIN" == "azure" ]; then
KUBELET_ID=$(az aks show -g $KUBE_GROUP -n $KUBE_NAME --query identityProfile.kubeletidentity.clientId -o tsv)
CONTROLLER_ID=$(az aks show -g $KUBE_GROUP -n $KUBE_NAME --query identity.principalId -o tsv)
NODE_GROUP=$(az aks show --resource-group $KUBE_GROUP --name $KUBE_NAME --query nodeResourceGroup -o tsv)

az role assignment create --role "Managed Identity Operator" --assignee $KUBELET_ID --scope /subscriptions/$SUBSCRIPTION_ID/resourcegroups/$NODE_GROUP
az role assignment create --role "Managed Identity Operator" --assignee $CONTROLLER_ID --scope /subscriptions/$SUBSCRIPTION_ID/resourcegroups/$NODE_GROUP
az role assignment create --role "Virtual Machine Contributor" --assignee $KUBELET_ID --scope /subscriptions/$SUBSCRIPTION_ID/resourcegroups/$NODE_GROUP
az role assignment create --role "Reader" --assignee $KUBELET_ID --scope /subscriptions/$SUBSCRIPTION_ID/resourcegroups/$APPGW_GROUP

fi

helm repo add aad-pod-identity https://raw.githubusercontent.com/Azure/aad-pod-identity/master/charts
helm repo update
helm upgrade aad-pod-identity --install --namespace kube-system aad-pod-identity/aad-pod-identity

#kubectl apply -f https://raw.githubusercontent.com/Azure/aad-pod-identity/v1.6.0/deploy/infra/deployment-rbac.yaml

echo "install application gateway ingress controller"

az identity create -g $NODE_GROUP -n $APPGW_NAME-id
sleep 5 # wait for replication
AGIC_ID_CLIENT_ID="$(az identity show -g $NODE_GROUP -n $APPGW_NAME-id  --query clientId -o tsv)"
AGIC_ID_RESOURCE_ID="$(az identity show -g $NODE_GROUP -n $APPGW_NAME-id  --query id -o tsv)"

NODES_RESOURCE_ID=$(az group show -n $NODE_GROUP -o tsv --query "id")
KUBE_GROUP_RESOURCE_ID=$(az group show -n $KUBE_GROUP -o tsv --query "id")
sleep 5 # wait for replication
az role assignment create --role "Contributor" --assignee $AGIC_ID_CLIENT_ID --scope $APPGW_RESOURCE_ID
az role assignment create --role "Reader" --assignee $AGIC_ID_CLIENT_ID --scope $KUBE_GROUP_RESOURCE_ID # might not be needed
az role assignment create --role "Reader" --assignee $AGIC_ID_CLIENT_ID --scope $NODES_RESOURCE_ID # might not be needed
az role assignment create --role "Reader" --assignee $AGIC_ID_CLIENT_ID --scope /subscriptions/$SUBSCRIPTION_ID/resourcegroups/$APPGW_GROUP

helm repo add application-gateway-kubernetes-ingress https://appgwingress.blob.core.windows.net/ingress-azure-helm-package/
helm repo update

helm upgrade ingress-azure application-gateway-kubernetes-ingress/ingress-azure \
     --namespace kube-system \
     --install \
     --set appgw.name=$APPGW_NAME \
     --set appgw.resourceGroup=$APPGW_GROUP \
     --set appgw.subscriptionId=$SUBSCRIPTION_ID \
     --set appgw.usePrivateIP=false \
     --set appgw.shared=false \
     --set armAuth.type=aadPodIdentity \
     --set armAuth.identityClientID=$AGIC_ID_CLIENT_ID \
     --set armAuth.identityResourceID=$AGIC_ID_RESOURCE_ID \
     --set rbac.enabled=true \
     --set verbosityLevel=3 \
     --set kubernetes.watchNamespace=default

sleep 120 # this might take a while to configure correctly

if [ "$KUBE_CNI_PLUGIN" == "kubenet" ]; then

AKS_NODE_NSG=$(az network nsg list -g ${NODE_GROUP} --query "[].id | [0]" -o tsv)

az network route-table create -g $APPGW_GROUP --name $APPGW_NAME-rt

APPGW_ROUTE_TABLE_ID=$(az network route-table show -g ${APPGW_GROUP} -n $APPGW_NAME-rt --query "id" -o tsv)

az network nsg create --name $APPGW_NAME-nsg --resource-group $APPGW_GROUP --location $LOCATION

# az network nsg rule create --name appgwrule --nsg-name $APPGW_NAME-nsg --resource-group $APPGW_GROUP --priority 110 \
#     --source-address-prefixes '*' --source-port-ranges '*' \
#     --destination-address-prefixes '*' --destination-port-ranges '*' --access Allow --direction Inbound \
#     --protocol "*" --description "Required allow rule for AppGW."

az network nsg rule create --name Allow_GWM --nsg-name $APPGW_NAME-nsg --priority 100 --resource-group $APPGW_GROUP --access Allow --direction Inbound --destination-port-ranges 65200-65535 --source-address-prefixes GatewayManager --description "Required for Gateway Manager."

az network nsg rule create --name agic_allow --nsg-name $APPGW_NAME-nsg --resource-group $APPGW_GROUP --priority 120 \
    --source-address-prefixes '*' --source-port-ranges '*' \
    --destination-address-prefixes "$APPGW_PUBLIC_IP" --destination-port-ranges '80' --access Allow --direction Inbound \
    --protocol "*" --description "Required allow rule for Ingress Controller."

#az network nsg rule create --name Allow_AzureLoadBalancer --nsg-name $APPGW_NAME-nsg --priority 110 --resource-group $APPGW_GROUP --access Allow --direction Inbound --source-address-prefixes AzureLoadBalancer
#az network nsg rule create --name DenyAllInbound_Internet --nsg-name $APPGW_NAME-nsg --priority 200 --resource-group $APPGW_GROUP --access Deny --direction Inbound --source-address-prefixes Internet

APPGW_NSG=$(az network nsg list -g ${APPGW_GROUP} --query "[].id | [0]" -o tsv)

az network vnet subnet update --route-table $APPGW_ROUTE_TABLE_ID --network-security-group $APPGW_NSG --ids $APPGW_SUBNET_ID

AKS_ROUTES=$(az network route-table route list --resource-group $VNET_GROUP --route-table-name $KUBE_NAME-rt)

az network route-table route list --resource-group $VNET_GROUP --route-table-name $KUBE_NAME-rt --query "[][name,addressPrefix,nextHopIpAddress]" -o tsv |
while read -r name addressPrefix nextHopIpAddress; do
   echo "checking route $name"
   echo "creating new hop $name selecting $addressPrefix configuring $nextHopIpAddress as next hop"
   az network route-table route create --resource-group $APPGW_GROUP --name $name --route-table-name $APPGW_NAME-rt --address-prefix $addressPrefix --next-hop-type VirtualAppliance --next-hop-ip-address $nextHopIpAddress --subscription $SUBSCRIPTION_ID
done


az network route-table route list --resource-group $APPGW_GROUP --route-table-name $APPGW_NAME-rt 

fi

kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/logging/dummy-logger/depl-logger.yaml
kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/logging/dummy-logger/svc-logger.yaml

cat <<EOF | kubectl apply -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: dummy-logger
  annotations:
    kubernetes.io/ingress.class: azure/application-gateway
spec:
  rules:
  - host: $APPGW_PUBLIC_IP.xip.io
    http:
      paths:
      - backend:
          serviceName: dummy-logger
          servicePort: 80
EOF

open "http://$APPGW_PUBLIC_IP.xip.io/ping"

# az aks enable-addons -n $KUBE_NAME -g $KUBE_GROUP -a ingress-appgw --appgw-id $APPGW_RESOURCE_ID


cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: centos
spec:
  containers:
  - name: centoss
    image: centos
    ports:
    - containerPort: 80
    command:
    - sleep
    - "3600"
EOF

kubectl exec -ti centos -- /bin/bash
