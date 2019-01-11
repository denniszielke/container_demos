# Setting up Firewall + AKS
https://docs.microsoft.com/en-us/azure/firewall/scripts/sample-create-firewall-test
https://docs.microsoft.com/en-us/azure/firewall/log-analytics-samples
https://raw.githubusercontent.com/Azure/azure-docs-json-samples/master/azure-firewall/AzureFirewall.omsview


0. Variables
```
SUBSCRIPTION_ID=""
KUBE_GROUP="kube_fw_net"
KUBE_NAME="dzkube"
LOCATION="westeurope"
KUBE_VNET_NAME="knets"
KUBE_FW_SUBNET_NAME="AzureFirewallSubnet"
KUBE_ING_SUBNET_NAME="ing-4-subnet"
KUBE_AGENT_SUBNET_NAME="aks-5-subnet"
FW_NAME="dzkubefw"
FW_IP_NAME="azureFirewalls-ip"
KUBE_VERSION="1.11.5"
SERVICE_PRINCIPAL_ID=
SERVICE_PRINCIPAL_SECRET=

```

Select subscription
```
az account set --subscription $SUBSCRIPTION_ID
```

1. Create the resource group
```
az group create -n $KUBE_GROUP -l $LOCATION
```

2. Create VNETs
```
az network vnet create -g $KUBE_GROUP -n $KUBE_VNET_NAME 
```

Assign permissions on vnet
```
az role assignment create --role "Contributor" --assignee $SERVICE_PRINCIPAL_ID -g $KUBE_GROUP
```

3. Create Subnets

```
az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_FW_SUBNET_NAME --address-prefix 10.0.3.0/24
az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_ING_SUBNET_NAME --address-prefix 10.0.4.0/24
az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_AGENT_SUBNET_NAME --address-prefix 10.0.5.0/24 --service-endpoints Microsoft.Sql Microsoft.AzureCosmosDB Microsoft.KeyVault Microsoft.Storage
```

4. Create the aks cluster

create cluster without rbac
```

KUBE_AGENT_SUBNET_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$KUBE_GROUP/providers/Microsoft.Network/virtualNetworks/$KUBE_VNET_NAME/subnets/$KUBE_AGENT_SUBNET_NAME"
```

with kubenet
```
az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --node-count 2  --ssh-key-value ~/.ssh/id_rsa.pub --network-plugin kubenet --vnet-subnet-id $KUBE_AGENT_SUBNET_ID --docker-bridge-address 172.17.0.1/16 --dns-service-ip 10.2.0.10 --service-cidr 10.2.0.0/24 --client-secret $SERVICE_PRINCIPAL_SECRET --service-principal $SERVICE_PRINCIPAL_ID --kubernetes-version $KUBE_VERSION --enable-rbac --node-vm-size "Standard_D2s_v3"
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

FW_PUBLIC_IP=$(az network public-ip show -g $KUBE_GROUP -n $FW_IP_NAME --query ipAddress)
FW_PRIVATE_IP="10.0.3.4"

AKS_MC_RG=$(az group list --query "[?starts_with(name, 'MC_${KUBE_GROUP}')].name | [0]" --output tsv)
ROUTE_TABLE_ID=$(az network route-table list -g ${AKS_MC_RG} --query "[].id | [0]" -o tsv)
ROUTE_TABLE_NAME=$(az network route-table list -g ${AKS_MC_RG} --query "[].name | [0]" -o tsv)
AKS_NODE_NSG=$(az network nsg list -g ${AKS_MC_RG} --query "[].id | [0]" -o tsv)

az network vnet subnet update --resource-group $KUBE_GROUP --route-table $ROUTE_TABLE_ID --network-security-group $AKS_NODE_NSG --ids $KUBE_AGENT_SUBNET_ID

az network route-table route create --resource-group $AKS_MC_RG --name $FW_ROUTE_NAME --route-table-name $ROUTE_TABLE_NAME --address-prefix 0.0.0.0/0 --next-hop-type VirtualAppliance --next-hop-ip-address $FW_PRIVATE_IP --subscription $SUBSCRIPTION_ID

az network route-table route list --resource-group $AKS_MC_RG --route-table-name $ROUTE_TABLE_NAME 
````

7. Add firewall rules

Add network rule

az network firewall network-rule create --firewall-name $FW_NAME --collection-name "aksnetwork" --destination-addresses "*"  --destination-ports "22, 443" --item-name "allow network" --protocols "TCP" --resource-group $KUBE_GROUP --source-addresses "*" --action "Allow" --description "aks network rule" --priority 100

* TCP - * - * - 22
* TCP - * - * - 443

Add application rule for aks
```
$Azfw = Get-AzureRmFirewall -ResourceGroupName $RG
$Rule = New-AzureRmFirewallApplicationRule -Name AKS -Protocol "http:80","https:443" -TargetFqdn "*azmk8s.io,*azureedge.net,*auth.docker.io,*blob.core.windows.net,*azure-automation.net,*opinsights.azure.com,*management.azure.com,*login.microsoftonline.com,*ubuntu.com,*vo.msecnd.net,*storage.googleapis.com,k8s.gcr.io,*.cloudflare.docker.io,*.microsoft.com,*.snapcraft.io,registry-1.docker.io, production.cloudflare.docker.com"
$RuleCollection = New-AzureRmFirewallApplicationRuleCollection -Name AKS-Outgoing -Priority 101 -Rule $Rule -ActionType "Allow"
$Azfw.ApplicationRuleCollections = $RuleCollection
Set-AzureRmFirewall -AzureFirewall $Azfw
```