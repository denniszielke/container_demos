# Create container cluster in a VNET (ACS Preview)
https://docs.microsoft.com/en-us/cli/azure/acs?view=azure-cli-latest#az_acs_create

0. Variables
```
SUBSCRIPTION_ID=""
KUBE_GROUP="kubevnet"
KUBE_NAME="dzkubenet"
LOCATION="ukwest"
KUBE_VNET_NAME="KVNET"
KUBE_AGENT_SUBNET_NAME="KVAGENTS"
KUBE_MASTER_SUBNET_NAME="KVMASTERS"
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

3. Create Subnets

```
az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_MASTER_SUBNET_NAME --address-prefix 10.0.0.0/24
az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_AGENT_SUBNET_NAME --address-prefix 10.0.1.0/24
```

4. Create the acs cluster
```
KUBE_AGENT_SUBNET_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$KUBE_GROUP/providers/Microsoft.Network/virtualNetworks/$KUBE_VNET_NAME/subnets/$KUBE_AGENT_SUBNET_NAME"
KUBE_MASTER_SUBNET_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$KUBE_GROUP/providers/Microsoft.Network/virtualNetworks/$KUBE_VNET_NAME/subnets/$KUBE_MASTER_SUBNET_NAME"
az acs create --orchestrator-type Kubernetes --resource-group $KUBE_GROUP --name $KUBE_NAME --agent-count 3 --generate-ssh-keys --agent-vnet-subnet-id $KUBE_AGENT_SUBNET_ID --master-vnet-subnet-id $KUBE_MASTER_SUBNET_ID --master-first-consecutive-static-ip "10.0.0.5"
```

Verify
```
az acs show --resource-group $KUBE_GROUP --name $KUBE_NAME
```

5. Export the kubectrl credentials files
```
az acs kubernetes get-credentials --resource-group $KUBE_GROUP --name $KUBE_NAME
```

or If you are not using the Azure Cloud Shell and don’t have the Kubernetes client kubectl, run 
```
az acs kubernetes install-cli
```

or download the file manually
```
scp azureuser@($KUBE_NAME)mgmt.westeurope.cloudapp.azure.com:.kube/config $HOME/.kube/config
```

6. Find out the route table name and update the network
https://github.com/Azure/ACS/blob/master/docs/VNET/README.md
```
KUBE_ROUTE_TABLE_NAME="k8s-master-21341239-routetable"
KUBE_ROUTE_TABLE="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/"$KUBE_GROUP"_"$KUBE_NAME"_"$LOCATION"/providers/Microsoft.Network/routeTables/$KUBE_ROUTE_TABLE_NAME"
az network vnet subnet update --resource-group $KUBE_GROUP --vnet-name $KUBE_VNET_NAME --name $KUBE_MASTER_SUBNET_NAME --route-table $KUBE_ROUTE_TABLE --address-prefix "10.0.0.0/24"
```

or
https://github.com/Azure/ACS/blob/master/announcements/2017-08-22_scenario_usage.md#custom-vnet-and-ports
#!/bin/bash
rt=$(az network route-table list -g GROUPNAME -o json | jq -r '.[].id')
az network vnet subnet update -n $KUBE_VNET_NAME -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME --route-table $rt

7. Check that everything is running ok
```
kubectl version
kubectl config current-contex
```

Use flag to use context
```
kubectl --kube-context
```


# Delete everything
```
az group delete -n $KUBE_GROUP
```
