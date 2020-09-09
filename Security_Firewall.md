# Setting up Firewall + AKS
Every now and then we get the question on how to lock down ingoing to and outgoing traffic from the kubernetes cluster in azure. One option that can be set up relativly easy but is not documented in detail is using the Azure Firewall (https://azure.microsoft.com/en-us/services/azure-firewall/).
The end result will look like this and requires some steps to configure the vnet, subnets, routetable, firewall rules and azure kubernetes services which are described below:
![](/img/aks-firewall.png)

My personal recommendation on this scenario is to use the firewall to diagnose the network dependencies of your applications - which is why I am also documenting the services that are currently needed for aks to run. If you turn on the rules to block outgoing traffic, you risk that your cluster breaks if the engineering team brings in additional required network dependencies.

## setting up the vnet

First we will setup the vnet - I prefer using azure cli over powershell but you can easy achieve the same using terraform or arm. If you have preferences on the naming conventions please adjust the variables below. In most companies the vnet is provided by the networking team so we should assume that the network configuration will not be done by the teams which is maintaining the aks cluster.


0. Variables
```
SUBSCRIPTION_ID="" # here enter your subscription id
KUBE_GROUP="kubes_fw_knet" # here enter the resources group name of your aks cluster
KUBE_NAME="dzkubekube" # here enter the name of your kubernetes resource
LOCATION="westeurope" # here enter the datacenter location
KUBE_VNET_NAME="knets" # here enter the name of your vnet
KUBE_FW_SUBNET_NAME="AzureFirewallSubnet" # this you cannot change
KUBE_ING_SUBNET_NAME="ing-4-subnet" # here enter the name of your ingress subnet
KUBE_AGENT_SUBNET_NAME="aks-5-subnet" # here enter the name of your aks subnet
FW_NAME="dzkubenetfw" # here enter the name of your azure firewall resource
FW_IP_NAME="azureFirewalls-ip" # here enter the name of your public ip resource for the firewall
KUBE_VERSION="1.11.5" # here enter the kubernetes version of your aks
SERVICE_PRINCIPAL_ID= # here enter the service principal of your aks
SERVICE_PRINCIPAL_SECRET= # here enter the service principal secret
```

1. Select subscription, create the resource group and the vnet
```

az feature register --name APIServerSecurityPreview --namespace Microsoft.ContainerService
az feature list -o table --query "[?contains(name, 'Microsoft.Container‐Service/APIServerSecurityPreview')].{Name:name,State:properties.state}"
az provider register --namespace Microsoft.ContainerService

az account set --subscription $SUBSCRIPTION_ID

az group create -n $KUBE_GROUP -l $LOCATION

az network vnet create -g $KUBE_GROUP -n $KUBE_VNET_NAME 
```

2. Assign permissions on vnet for your service principal - usually "virtual machine contributor is enough"
```
az role assignment create --role "Contributor" --assignee $SERVICE_PRINCIPAL_ID -g $KUBE_GROUP
az role assignment create --role "Virtual Machine Contributor" --assignee $SERVICE_PRINCIPAL_ID -g $KUBE_GROUP
```

3. Create subnets for the firewall, ingress and aks

```
az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_FW_SUBNET_NAME --address-prefix 10.0.3.0/24
az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_ING_SUBNET_NAME --address-prefix 10.0.4.0/24
az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_AGENT_SUBNET_NAME --address-prefix 10.0.5.0/24 --service-endpoints Microsoft.Sql Microsoft.AzureCosmosDB Microsoft.KeyVault Microsoft.Storage
```

## setting up the cluster
As you might know there are two different options on how networking can be set up in aks called "Basic networking" and "Advanced Networking". I am not going into detail how they differ - you can look it up here: https://docs.microsoft.com/en-us/azure/aks/concepts-network . For the usage of azure firewall in this scenario it does not matter since both options work but need to be configured differently, which is why I am documenting both options.

### setting up aks cluster with basic networking
Basic networking requires to modify the routetable that will be created by the aks deployment, add another route and point it towards the internal ip of the azure firewall. If you want to use advanced networking skip this section and continue below.

4. Create the aks cluster

```
KUBE_AGENT_SUBNET_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$KUBE_GROUP/providers/Microsoft.Network/virtualNetworks/$KUBE_VNET_NAME/subnets/$KUBE_AGENT_SUBNET_NAME"

az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --node-count 2  --ssh-key-value ~/.ssh/id_rsa.pub --network-plugin kubenet --vnet-subnet-id $KUBE_AGENT_SUBNET_ID --docker-bridge-address 172.17.0.1/16 --dns-service-ip 10.2.0.10 --service-cidr 10.2.0.0/24 --client-secret $SERVICE_PRINCIPAL_SECRET --service-principal $SERVICE_PRINCIPAL_ID --kubernetes-version $KUBE_VERSION --enable-rbac --node-vm-size "Standard_D2s_v3" --vm-set-type VirtualMachineScaleSets --load-balancer-sku standard
```

5. Create azure firewall
* this is currently not possible via cli - the creation of the azure firewall in that vnet is only possible with the azure portal *
```

az extension add --name azure-firewall
az network public-ip create -g $KUBE_GROUP -n $FW_NAME-ip --sku Standard
az network firewall create --name $FW_NAME --resource-group $KUBE_GROUP --location $LOCATION
az network firewall ip-config create --firewall-name $FW_NAME --name $FW_NAME --public-ip-address $FW_NAME-ip --resource-group $KUBE_GROUP --vnet-name $KUBE_VNET_NAME
FW_PRIVATE_IP=$(az network firewall show -g $KUBE_GROUP -n $FW_NAME --query "ipConfigurations[0].privateIpAddress" -o tsv)
az monitor log-analytics workspace create --resource-group $KUBE_GROUP --workspace-name $FW_NAME-lgw --location $LOCATION

KUBE_AGENT_SUBNET_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$KUBE_GROUP/providers/Microsoft.Network/virtualNetworks/$KUBE_VNET_NAME/subnets/$KUBE_AGENT_SUBNET_NAME"
az network route-table create -g $KUBE_GROUP --name $FW_NAME-rt
az network route-table route create --resource-group $KUBE_GROUP --name $FW_NAME --route-table-name $FW_NAME-rt --address-prefix 0.0.0.0/0 --next-hop-type VirtualAppliance --next-hop-ip-address $FW_PRIVATE_IP
az network vnet subnet update --route-table $FW_NAME-rt --ids $KUBE_AGENT_SUBNET_ID
az network route-table route list --resource-group $KUBE_GROUP --route-table-name $FW_NAME-rt

az network firewall network-rule create --firewall-name $FW_NAME --collection-name "time" --destination-addresses "*"  --destination-ports 123 --name "allow network" --protocols "UDP" --resource-group $KUBE_GROUP --source-addresses "*" --action "Allow" --description "aks node time sync rule" --priority 101
az network firewall network-rule create --firewall-name $FW_NAME --collection-name "dns" --destination-addresses "*"  --destination-ports 53 --name "allow network" --protocols "UDP" --resource-group $KUBE_GROUP --source-addresses "*" --action "Allow" --description "aks node dns rule" --priority 102
az network firewall network-rule create --firewall-name $FW_NAME --collection-name "servicetags" --destination-addresses "AzureContainerRegistry" "MicrosoftContainerRegistry" "AzureActiveDirectory" "AzureMonitor" --destination-ports "*" --name "allowservice  tags" --protocols "Any" --resource-group $KUBE_GROUP --source-addresses "*" --action "Allow" --description "allow service tags" --priority 110
az network firewall network-rule create --firewall-name $FW_NAME --collection-name "hcp" --destination-addresses "*" --destination-ports "1194" --name "allow master tags" --protocols "Any" --resource-group $KUBE_GROUP --source-addresses "*" --action "Allow" --description "allow service tags" --priority 120

az network firewall application-rule create --firewall-name $FW_NAME --resource-group $KUBE_GROUP --collection-name 'aksfwar' -n 'fqdn' --source-addresses '*' --protocols 'http=80' 'https=443' --fqdn-tags "AzureKubernetesService" --action allow --priority 101
az network firewall application-rule create  --firewall-name $FW_NAME --collection-name "osupdates" --name "allow network" --protocols http=80 https=443 --source-addresses "*" --resource-group $KUBE_GROUP --action "Allow" --target-fqdns "download.opensuse.org" "security.ubuntu.com" "packages.microsoft.com" "azure.archive.ubuntu.com" "changelogs.ubuntu.com" "snapcraft.io" "api.snapcraft.io" "motd.ubuntu.com"  --priority 102
```

6. Create UDR
After the deployment we create another route in the routetable and associate the route table to the subnet - which is required due to the known bug that is currently in aks (https://github.com/Azure/AKS/issues/718)
```
FW_ROUTE_NAME="${FW_NAME}_fw_r"

FW_PUBLIC_IP=$(az network public-ip show -g $KUBE_GROUP -n $FW_IP_NAME --query ipAddress)
FW_PRIVATE_IP="10.0.3.4"

AKS_MC_RG=$(az group list --query "[?starts_with(name, 'MC_${KUBE_GROUP}')].name | [0]" --output tsv)
ROUTE_TABLE_ID=$(az network route-table list -g ${AKS_MC_RG} --query "[].id | [0]" -o tsv)
ROUTE_TABLE_NAME=$(az network route-table list -g ${AKS_MC_RG} --query "[].name | [0]" -o tsv)
AKS_NODE_NSG=$(az network nsg list -g ${AKS_MC_RG} --query "[].id | [0]" -o tsv)

az network vnet subnet update --resource-group $KUBE_GROUP --route-table $ROUTE_TABLE_ID --network-security-group $AKS_NODE_NSG --ids $KUBE_AGENT_SUBNET_ID

az network route-table route create --resource-group $AKS_MC_RG --name $FW_ROUTE_NAME --route-table-name $ROUTE_TABLE_NAME --address-prefix 0.0.0.0/0 --next-hop-type VirtualAppliance --next-hop-ip-address $FW_PRIVATE_IP --subscription $SUBSCRIPTION_ID

az network route-table route list --resource-group $AKS_MC_RG --route-table-name $ROUTE_TABLE_NAME 
```

## setting up cluster with azure cni
Advanced networking is a bit simpler but requires you to create the routetable first, create the route and then again associate it with the aks subnet.

4. Create the aks cluster

```
KUBE_AGENT_SUBNET_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$KUBE_GROUP/providers/Microsoft.Network/virtualNetworks/$KUBE_VNET_NAME/subnets/$KUBE_AGENT_SUBNET_NAME"

az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --node-count 2  --ssh-key-value ~/.ssh/id_rsa.pub --network-plugin azure --vnet-subnet-id $KUBE_AGENT_SUBNET_ID --docker-bridge-address 172.17.0.1/16 --dns-service-ip 10.2.0.10 --service-cidr 10.2.0.0/24 --client-secret $SERVICE_PRINCIPAL_SECRET --service-principal $SERVICE_PRINCIPAL_ID --kubernetes-version $KUBE_VERSION --enable-rbac --node-vm-size "Standard_D2s_v3" --max-pods 15
```

5. Create azure firewall
* this is currently not possible via cli - the creation of the azure firewall in that vnet is only possible with the azure portal *
```
az extension add --name azure-firewall
az network firewall create --name $FW_NAME --resource-group $KUBE_GROUP --location $LOCATION
```

6. Create UDR
```
FW_ROUTE_NAME="${FW_NAME}_fw_r"
FW_ROUTE_TABLE_NAME="${FW_NAME}_fw_rt"

KUBE_AGENT_SUBNET_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$KUBE_GROUP/providers/Microsoft.Network/virtualNetworks/$KUBE_VNET_NAME/subnets/$KUBE_AGENT_SUBNET_NAME"

FW_PUBLIC_IP=$(az network public-ip show -g $KUBE_GROUP -n $FW_IP_NAME --query ipAddress)
FW_PRIVATE_IP="10.0.3.4"

az network route-table create -g $KUBE_GROUP --name $FW_ROUTE_TABLE_NAME

az network vnet subnet update --resource-group $KUBE_GROUP --route-table $FW_ROUTE_TABLE_NAME --ids $KUBE_AGENT_SUBNET_ID

az network route-table route create --resource-group $KUBE_GROUP --name $FW_ROUTE_NAME --route-table-name $FW_ROUTE_TABLE_NAME --address-prefix 0.0.0.0/0 --next-hop-type VirtualAppliance --next-hop-ip-address $FW_PRIVATE_IP --subscription $SUBSCRIPTION_ID

az network route-table route list --resource-group $KUBE_GROUP --route-table-name $FW_ROUTE_TABLE_NAME 
```

## Configure azure firewall

Setup the azure firewall diagnostics and create a dashboard by importing this file:
https://docs.microsoft.com/en-us/azure/firewall/tutorial-diagnostics
https://raw.githubusercontent.com/Azure/azure-docs-json-samples/master/azure-firewall/AzureFirewall.omsview

get hcp ip (if the feature is active you can resolve your dedicated api server ip)
```
HCP_IP=$(kubectl get endpoints -o=jsonpath='{.items[?(@.metadata.name == "kubernetes")].subsets[].addresses[].ip}')
```
Add firewall rules

Add network rule for 9000 (tunnel), and 443 (api server) for aks to work - this is needed for aks
Add network rule for 123 (time sync) and 53 (dns) for the worker nodes - this is optional for ubuntu patches
```
az network firewall network-rule create --firewall-name $FW_NAME --collection-name "aksnetwork" --destination-addresses $HCP_IP  --destination-ports 9000 --name "allow network" --protocols "TCP" --resource-group $KUBE_GROUP --source-addresses "*" --action "Allow" --description "aks network rule" --priority 100

az network firewall network-rule create --firewall-name $FW_NAME --collection-name "time" --destination-addresses "*"  --destination-ports 123 --name "allow network" --protocols "UDP" --resource-group $KUBE_GROUP --source-addresses "*" --action "Allow" --description "aks node time sync rule" --priority 101

az network firewall network-rule create --firewall-name $FW_NAME --collection-name "dns" --destination-addresses "*"  --destination-ports 53 --name "allow network" --protocols "UDP" --resource-group $KUBE_GROUP --source-addresses "*" --action "Allow" --description "aks node dns rule" --priority 102

az network firewall network-rule create --firewall-name $FW_NAME --collection-name "kubesvc" --destination-addresses "*"  --destination-ports 443 --name "allow network" --protocols "TCP" --resource-group $KUBE_GROUP --source-addresses "*" --action "Allow" --description "aks kube svc rule" --priority 103

az network firewall network-rule create --firewall-name $FW_NAME --collection-name "ssh" --destination-addresses "*"  --destination-ports 22 --name "allow network" --protocols "TCP" --resource-group $KUBE_GROUP --source-addresses "*" --action "Allow" --description "aks ssh access rule" --priority 104
```

See complete list of external dependencies:
https://docs.microsoft.com/en-us/azure/aks/limit-egress-traffic

Required application rule for:
- `*<region>.azmk8s.io` (eg. `*westeurope.azmk8s.io`) – this is the dns that is running your masters
- `*cloudflare.docker.io` – docker hub cdn
- `*registry-1.docker.io` – docker hub
- `*azurecr.io` – storing your images in azure container registry
- `*blob.core.windows.net` – the storage behind acr
- `k8s.gcr.io` - images stored in gcr
- `storage.googleapis.com` - storage behind google gcr

Optional:
- `*.ubuntu.com, download.opensuse.org` – This is needed for security patches and updates - if the customer wants them to be applied automatically
- `snapcraft.io, api.snapcraft.io` - used by ubuntu for packages
- `packages.microsoft.com`- packages from microsoft
- `login.microsoftonline.com` - for azure aad login
- `dc.services.visualstudio.com` - application insights
- `*.opinsights.azure.com` - azure monitor
- `*.monitoring.azure.com` - azure monitor
- `*.management.azure.com` - azure tooling

### create the application rules

![](/img/hcp-new.png)

```
az network firewall application-rule create  --firewall-name $FW_NAME --collection-name "aksbasics" --name "allow network" --protocols http=80 https=443 --source-addresses "*" --resource-group $KUBE_GROUP --action "Allow" --target-fqdns "*.azmk8s.io" "aksrepos.azurecr.io" "*.blob.core.windows.net" "mcr.microsoft.com" "*.cdn.mscr.io" "management.azure.com" "login.microsoftonline.com" "packages.microsoft.com" "acs-mirror.azureedge.net" "security.ubuntu.com" "api.snapcraft.io" "*auth.docker.io" "*cloudflare.docker.io" "*cloudflare.docker.com" "*registry-1.docker.io" --priority 100

az network firewall application-rule create  --firewall-name $FW_NAME --collection-name "monitoring" --name "allow network" --protocols http=80 https=443 --source-addresses "*" --resource-group $KUBE_GROUP --action "Allow" --target-fqdns "dc.services.visualstudio.com" "*.ods.opinsights.azure.com	" "*.oms.opinsights.azure.com" "*.microsoftonline.com" "*.monitoring.azure.com" --priority 101

az network firewall application-rule create  --firewall-name $FW_NAME --collection-name "osupdates" --name "allow network" --protocols http=80 https=443 --source-addresses "*" --resource-group $KUBE_GROUP --action "Allow" --target-fqdns "security.ubuntu.com" "azure.archive.ubuntu.com" "changelogs.ubuntu.com"  --priority 102
```

test the outgoing traffic
```
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
```

```
kubectl exec -ti centos -- /bin/bash
curl bad.org
curl ubuntu.com

kubectl get endpoints -o=jsonpath='{.items[?(@.metadata.name == "kubernetes")].subsets[].addresses[].ip}' -o wide --all-namespaces
```

### public ip NET rules
* THIS IS ONLY REQUIRED IF YOU HAVE PUBLIC IP LOADBALANCERS IN AKS*

create a pod 
```
kubectl run nginx --image=nginx --port=80
```

expose it via internal lb
```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: nginx-internal
  annotations:
    service.beta.kubernetes.io/azure-load-balancer-internal: "true"
    service.beta.kubernetes.io/azure-load-balancer-internal-subnet: "ing-4-subnet"
spec:
  type: LoadBalancer
  loadBalancerIP: 10.0.4.25
  ports:
  - port: 80
  selector:
    name: nginx
EOF
```

get the internal ip adress
```
SERVICE_IP=$(kubectl get svc nginx-internal --template="{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}")
```

create an azure firewall nat rule for that internal service
```
az network firewall nat-rule create  --firewall-name $FW_NAME --collection-name "inboundlbrules" --name "allow inbound load balancers" --protocols "TCP" --source-addresses "*" --resource-group $KUBE_GROUP --action "Dnat"  --destination-addresses $FW_PUBLIC_IP --destination-ports 80 --translated-address $SERVICE_IP --translated-port "80"  --priority 101
open http://$FW_PUBLIC_IP:80
```

now you can acces the internal service by going to the $FW_PUBLIC_IP on port 80
