# Setting up Firewall + AKS
https://docs.microsoft.com/en-us/azure/firewall/scripts/sample-create-firewall-test
https://docs.microsoft.com/en-us/azure/firewall/log-analytics-samples
https://raw.githubusercontent.com/Azure/azure-docs-json-samples/master/azure-firewall/AzureFirewall.omsview


0. Variables
```
SUBSCRIPTION_ID=""
KUBE_GROUP="kub_ter_a_m_speedeply"
KUBE_NAME="speedeply"
LOCATION="eastus"
KUBE_VNET_NAME="speedeply-vnet"
KUBE_AGENT_SUBNET_NAME="aks-5-subnet"
KUBE_FW_SUBNET_NAME="AzureFirewallSubnet"
FW_NAME="dzfwapi"
FW_IP_NAME="azureFirewalls-ip"
KUBE_VERSION="1.11.4"
SERVICE_PRINCIPAL_ID=
SERVICE_PRINCIPAL_SECRET=
AAD_APP_NAME=""
AAD_APP_ID=
AAD_APP_SECRET=
AAD_CLIENT_NAME=
AAD_CLIENT_ID=
TENANT_ID=

```

Select subscription
```
az account set --subscription $SUBSCRIPTION_ID
```

1. Create azure firewall
```
az network firewall create -n $FW_NAME -g $KUBE_GROUP -l $LOCATION
```

2. Create UDR
```
FW_ROUTE_NAME=$FW_NAME"_fw_r"
FW_ROUTE_TABLE_NAME=$FW_NAME"_fw_rt"

FW_PUBLIC_IP=$(az network public-ip show -g $KUBE_GROUP -n $FW_IP_NAME --query ipAddress)
FW_PRIVATE_IP="10.0.6.4"

az network route-table create -g $KUBE_GROUP --name $FW_ROUTE_TABLE_NAME

az network route-table route create -g $KUBE_GROUP --name $FW_ROUTE_NAME --route-table-name $FW_ROUTE_TABLE_NAME --address-prefix 0.0.0.0/0 --next-hop-type VirtualAppliance --next-hop-ip-address $FW_PRIVATE_IP

az network vnet subnet update -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME --name $KUBE_AGENT_SUBNET_NAME --route-table $FW_ROUTE_TABLE_NAME
````

3. Add firewall rules

Add netowrk rule

* TCP - * - * - 22
* TCP - * - * - 443
* TCP - * - * - 10250

Add application rule for aks
```
$Azfw = Get-AzureRmFirewall -ResourceGroupName $RG
$Rule = New-AzureRmFirewallApplicationRule -Name AKS -Protocol "http:80","https:443" -TargetFqdn "*azmk8s.io,*azureedge.net,*auth.docker.io,*blob.core.windows.net,*azure-automation.net,*opinsights.azure.com,*management.azure.com,*login.microsoftonline.com,*ubuntu.com,*vo.msecnd.net,*storage.googleapis.com,k8s.gcr.io,*.cloudflare.docker.io,*.microsoft.com,*.snapcraft.io,registry-1.docker.io, production.cloudflare.docker.com"
$RuleCollection = New-AzureRmFirewallApplicationRuleCollection -Name AKS-Outgoing -Priority 101 -Rule $Rule -ActionType "Allow"
$Azfw.ApplicationRuleCollections = $RuleCollection
Set-AzureRmFirewall -AzureFirewall $Azfw
```