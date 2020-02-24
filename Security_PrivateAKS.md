# Setting up Firewall + Private Link AKS
Every now and then we get the question on how to build an AKS cluster that is not exposing or using any public IPs. Up until recently that was not possible because the AKS hosted control plane was using a public ip (that is no longer required if you leverage privatelink https://docs.microsoft.com/en-us/azure/aks/private-clusters) or the fact that your worker nodes still needed to have public IP attached to their standard load balancer (which is required to get ensure internet egress for container registries and such https://docs.microsoft.com/en-us/azure/aks/egress).
One option that can be set up relativly easy but is not documented in detail is using the Azure Firewall (https://azure.microsoft.com/en-us/services/azure-firewall/).
The end result will look like this and requires some steps to configure the vnet, subnets, routetable, firewall rules and azure kubernetes services which are described below:
![](/img/fullyprivateaks.png)


## setting up the vnet

First we will setup the vnet - I prefer using azure cli over powershell but you can easy achieve the same using terraform or arm. If you have preferences on the naming conventions please adjust the variables below. In most companies the vnet is provided by the networking team so we should assume that the network configuration will not be done by the teams which is maintaining the aks cluster.

0. Variables
```
SUBSCRIPTION_ID="" # here enter your subscription id
KUBE_GROUP="nopublicipaks" # here enter the resources group name of your aks cluster
KUBE_NAME="dzprivatekube" # here enter the name of your kubernetes resource
LOCATION="australiaeast" # here enter the datacenter location
VNET_GROUP="networks" # here the name of the resource group for the vnet and hub resources
KUBE_VNET_NAME="spoke1-kubevnet" # here enter the name of your vnet
KUBE_ING_SUBNET_NAME="ing-1-subnet" # here enter the name of your ingress subnet
KUBE_AGENT_SUBNET_NAME="aks-2-subnet" # here enter the name of your aks subnet
HUB_VNET_NAME="hub1-firewalvnet"
HUB_FW_SUBNET_NAME="AzureFirewallSubnet" # this you cannot change
HUB_JUMP_SUBNET_NAME="jumpbox-subnet"
FW_NAME="dzkubenetfw" # here enter the name of your azure firewall resource
FW_IP_NAME="azureFirewalls-ip" # here enter the name of your public ip resource for the firewall
KUBE_VERSION="1.15.7" # here enter the kubernetes version of your aks
SERVICE_PRINCIPAL_ID= # here enter the service principal of your aks
SERVICE_PRINCIPAL_SECRET= # here enter the service principal secret
```

1. Select subscription, create the resource group and the vnets
```

az account set --subscription $SUBSCRIPTION_ID

az group create -n $KUBE_GROUP -l $LOCATION
az group create -n $VNET_GROUP -l $LOCATION

az network vnet create -g $VNET_GROUP -n $HUB_VNET_NAME --address-prefixes 10.0.0.0/22
az network vnet create -g $VNET_GROUP -n $KUBE_VNET_NAME --address-prefixes 10.0.4.0/22
```

2. Assign permissions on vnet for your service principal - usually "virtual machine contributor is enough"
```
az role assignment create --role "Contributor" --assignee $SERVICE_PRINCIPAL_ID -g $VNET_GROUP
az role assignment create --role "Virtual Machine Contributor" --assignee $SERVICE_PRINCIPAL_ID -g $VNET_GROUP
```

3. Create subnets for the firewall, jumpbox, ingress and aks

```
az network vnet subnet create -g $VNET_GROUP --vnet-name $HUB_VNET_NAME -n $KUBE_FW_SUBNET_NAME --address-prefix 10.0.0.0/24
az network vnet subnet create -g $VNET_GROUP --vnet-name $HUB_VNET_NAME -n $HUB_JUMP_SUBNET_NAME --address-prefix 10.0.1.0/24
az network vnet subnet create -g $VNET_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_ING_SUBNET_NAME --address-prefix 10.0.4.0/24
az network vnet subnet create -g $VNET_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_AGENT_SUBNET_NAME --address-prefix 10.0.5.0/24 --service-endpoints Microsoft.KeyVault Microsoft.Storage
```

4. Create vnet peering between hub vnet and spoke vnet
```
az network vnet peering create -g $VNET_GROUP -n HubToSpoke1 --vnet-name $HUB_VNET_NAME --remote-vnet $KUBE_VNET_NAME --allow-vnet-access

az network vnet peering create -g $VNET_GROUP -n Spoke1ToHub --vnet-name $KUBE_VNET_NAME --remote-vnet $HUB_VNET_NAME --allow-vnet-access
```

## setting up the cluster
As you might know there are two different options on how networking can be set up in aks called "Basic networking" and "Advanced Networking". I am not going into detail how they differ - you can look it up here: https://docs.microsoft.com/en-us/azure/aks/concepts-network . For the usage of azure firewall in this scenario it does not matter since both options work but need to be configured differently, which is why I am documenting both options.

## setting up cluster with azure cni
Advanced networking is a bit simpler but requires you to create the routetable first, create the route and then again associate it with the aks subnet.

5. Create azure firewall
```
FW_PRIVATE_IP="10.0.0.4"
az network public-ip create -g $VNET_GROUP -n $FW_IP_NAME --sku Standard
az extension add --name azure-firewall
az network firewall create --name $FW_NAME --resource-group $VNET_GROUP --location $LOCATION
az network firewall ip-config create --firewall-name $FW_NAME --name $FW_NAME --public-ip-address $FW_IP_NAME --resource-group $VNET_GROUP --private-ip-address $FW_PRIVATE_IP --vnet-name $HUB_VNET_NAME
```

6. Create UDR and force traffic from the kubernetes subnet to the azure firewall
```
FW_ROUTE_NAME="${FW_NAME}_fw_r"
FW_ROUTE_TABLE_NAME="${FW_NAME}_fw_rt"

KUBE_AGENT_SUBNET_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$VNET_GROUP/providers/Microsoft.Network/virtualNetworks/$KUBE_VNET_NAME/subnets/$KUBE_AGENT_SUBNET_NAME"

az network route-table create -g $VNET_GROUP --name $FW_ROUTE_TABLE_NAME

az network vnet subnet update --resource-group $VNET_GROUP --route-table $FW_ROUTE_TABLE_NAME --ids $KUBE_AGENT_SUBNET_ID

az network route-table route create --resource-group $VNET_GROUP --name $FW_ROUTE_NAME --route-table-name $FW_ROUTE_TABLE_NAME --address-prefix 0.0.0.0/0 --next-hop-type VirtualAppliance --next-hop-ip-address $FW_PRIVATE_IP --subscription $SUBSCRIPTION_ID

az network route-table route list --resource-group $VNET_GROUP --route-table-name $FW_ROUTE_TABLE_NAME 
```

7. Deploy cluster
```

az group deployment create \
    --name privatecluster \
    --resource-group $KUBE_GROUP \
    --template-file "arm/fullyprivate.json" \
    --parameters "arm/zones_parameters.json" \
    --parameters "resourceName=$KUBE_NAME" \
        "location=$LOCATION" \
        "dnsPrefix=$KUBE_NAME" \
        "kubernetesVersion=$KUBE_VERSION" \
        "servicePrincipalClientId=$SERVICE_PRINCIPAL_ID" \
        "servicePrincipalClientSecret=$SERVICE_PRINCIPAL_SECRET" \
        "vnetSubnetID=$KUBE_AGENT_SUBNET_ID" --no-wait
```

## Configure azure firewall

Setup the azure firewall diagnostics and create a dashboard by importing this file:
https://docs.microsoft.com/en-us/azure/firewall/tutorial-diagnostics
https://raw.githubusercontent.com/Azure/azure-docs-json-samples/master/azure-firewall/AzureFirewall.omsview

Create Log Analytics workspace
```
az monitor log-analytics workspace create --resource-group $VNET_GROUP --workspace-name privateaksfwlogs --location $LOCATION
```

Add network rule for 123 (time sync) and 53 (dns) for the worker nodes - this is optional for ubuntu patches
```
az network firewall network-rule create --firewall-name $FW_NAME --collection-name "aksnetwork" --destination-addresses "*"  --destination-ports 9000 --name "allow network" --protocols "TCP" --resource-group $VNET_GROUP --source-addresses "*" --action "Allow" --description "aks network rule" --priority 100

az network firewall network-rule create --firewall-name $FW_NAME --collection-name "time" --destination-addresses "*"  --destination-ports 123 --name "allow time" --protocols "UDP" --resource-group $VNET_GROUP --source-addresses "*" --action "Allow" --description "aks node time sync rule" --priority 101

az network firewall network-rule create --firewall-name $FW_NAME --collection-name "dns" --destination-addresses "*"  --destination-ports 53 --name "allow dns" --protocols "UDP" --resource-group $VNET_GROUP --source-addresses "*" --action "Allow" --description "aks node dns rule" --priority 102


az network firewall network-rule create --firewall-name $FW_NAME --collection-name "kubesvc" --destination-addresses "*"  --destination-ports 443 --name "allow network" --protocols "TCP" --resource-group $VNET_GROUP --source-addresses "*" --action "Allow" --description "aks kube svc rule" --priority 103

az network firewall network-rule create --firewall-name $FW_NAME --collection-name "ssh" --destination-addresses "*"  --destination-ports 22 --name "allow network" --protocols "TCP" --resource-group $VNET_GROUP --source-addresses "*" --action "Allow" --description "aks ssh access rule" --priority 104

az network firewall network-rule create --firewall-name $FW_NAME --collection-name "servicetags" --destination-addresses "AzureContainerRegistry" "MicrosoftContainerRegistry" "AzureActiveDirectory" --destination-ports "*" --name "allow service tags" --protocols "Any" --resource-group $VNET_GROUP --source-addresses "*" --action "Allow" --description "allow service tags" --priority 110

az network firewall network-rule list --firewall-name $FW_NAME --resource-group $VNET_GROUP
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
az network firewall application-rule create  --firewall-name $FW_NAME --collection-name "aksbasics" --name "allow network" --protocols http=80 https=443 --source-addresses "*" --resource-group $VNET_GROUP --action "Allow" --target-fqdns "*.azmk8s.io" "aksrepos.azurecr.io" "*.blob.core.windows.net" "mcr.microsoft.com" "*.cdn.mscr.io" "acs-mirror.azureedge.net" "management.azure.com" "login.microsoftonline.com" "api.snapcraft.io" "*auth.docker.io" "*cloudflare.docker.io" "*cloudflare.docker.com" "*registry-1.docker.io" --priority 100

az network firewall application-rule create  --firewall-name $FW_NAME --collection-name "akstools" --name "allow network" --protocols http=80 https=443 --source-addresses "*" --resource-group $VNET_GROUP --action "Allow" --target-fqdns "download.opensuse.org" "packages.microsoft.com" "dc.services.visualstudio.com" "*.opinsights.azure.com" "*.monitoring.azure.com" "gov-prod-policy-data.trafficmanager.net" "apt.dockerproject.org" "nvidia.github.io" --priority 101

az network firewall application-rule create  --firewall-name $FW_NAME --collection-name "osupdates" --name "allow network" --protocols http=80 https=443 --source-addresses "*" --resource-group $VNET_GROUP --action "Allow" --target-fqdns "download.opensuse.org" "*.ubuntu.com" "packages.microsoft.com" "snapcraft.io" "api.snapcraft.io"  --priority 102
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
  - name: centos
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
curl superbad.org
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
    service.beta.kubernetes.io/azure-load-balancer-internal-subnet: "ing-1-subnet"
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

FW_PUBLIC_IP=$(az network public-ip show -g $VNET_GROUP -n $FW_IP_NAME --query ipAddress)

az network firewall nat-rule create  --firewall-name $FW_NAME --collection-name "inboundlbrules" --name "allow inbound load balancers" --protocols "TCP" --source-addresses "*" --resource-group $VNET_GROUP --action "Dnat"  --destination-addresses $FW_PUBLIC_IP --destination-ports 80 --translated-address 10.0.4.25 --translated-port "80"  --priority 101
open http://$FW_PUBLIC_IP:80
```

now you can acces the internal service by going to the $FW_PUBLIC_IP on port 80


