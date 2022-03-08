#!/bin/sh

set -e

DEPLOYMENT_NAME="arorunning" # here enter unique deployment name (ideally short and with letters for global uniqueness)
cluster_name="aro"
INFRA_RG="aro-infra"
KUBE_GROUP="aro-cluster"
LOCATION="northeurope" #"centralus" #"southcentralus" #"eastus2euap" #"westeurope" # here enter the datacenter location can be eastus or westeurope
KUBE_VNET_GROUP="aro-vnet"
KUBE_VNET_NAME="$DEPLOYMENT_NAME-vnet"
KUBE_FW_SUBNET_NAME="AzureFirewallSubnet" # this you cannot change
APPGW_SUBNET_NAME="gw-1-subnet"
KUBE_ING_SUBNET_NAME="ing-4-subnet" # here enter the name of your ingress subnet
MASTERS_SUBNET_NAME="masters-5-subnet"
WORKERS_SUBNET_NAME="workers-8-subnet" # here enter the name of your AKS subnet
VAULT_NAME="runningcodevault"
SUBSCRIPTION_ID=$(az account show --query id -o tsv) # here enter your subscription id
TENANT_ID=$(az account show --query tenantId -o tsv)
MY_OWN_OBJECT_ID=$(az ad signed-in-user show --query objectId --output tsv) # this will be your own aad object id
DOMAIN="running-code.de"
#az account set --subscription $SUBSCRIPTION_ID


purpose="aro"
keyvault_appid_secret_name="$purpose-sp-appid"
keyvault_password_secret_name="$purpose-sp-secret"
sp_app_id=$(az keyvault secret show --vault-name $VAULT_NAME -n $keyvault_appid_secret_name --query 'value' -o tsv | jq .value -r)
sp_app_secret=$(az keyvault secret show --vault-name $VAULT_NAME -n $keyvault_password_secret_name --query 'value' -o tsv | jq .value -r)

echo "found $sp_app_id id with secret $sp_app_secret"

# if [[ -z "$sp_app_id" ]] || [[ -z "$sp_app_secret" ]]
# then
#   echo "Creating service principal credentials and storing in AKV $keyvault_name..."
# else
#   echo "Service principal credentials successfully retrieved from AKV $keyvault_name"
# fi

akv_secret_name="openshift-pull-secret"
pull_secret=$(az keyvault secret show -n $akv_secret_name --vault-name $VAULT_NAME --query value -o tsv | jq .value -r)
# if [[ -z "${pull_secret}" ]]
# then
#   echo "Pull secret could not be retrieved from AKV $akv_name"
#   pullsecret_flag=""
# else
#   echo "Pull secret successfully retrieved from AKV $akv_name"
#   pullsecret_flag="--pull-secret $pull_secret"
# fi

echo "found pull secret $pull_secret"

if [ $(az group exists --name $ARO_GROUP) = false ]; then
    echo "creating resource group $ARO_GROUP..."
    az group create -n $ARO_GROUP -l $LOCATION -o none
    echo "resource group $ARO_GROUP created"
else   
    echo "resource group $ARO_GROUP already exists"
fi

if [ $(az group exists --name $KUBE_VNET_GROUP) = false ]; then
    echo "creating resource group $KUBE_VNET_GROUP..."
    az group create -n $KUBE_VNET_GROUP -l $LOCATION -o none
    echo "resource group $KUBE_VNET_GROUP created"
else   
    echo "resource group $KUBE_VNET_GROUP already exists"
fi

echo "setting up vnet"

VNET_RESOURCE_ID=$(az network vnet list -g $KUBE_VNET_GROUP --query "[?contains(name, '$KUBE_VNET_NAME')].id" -o tsv)
if [ "$VNET_RESOURCE_ID" == "[]" ]; then
    echo "creating vnet $KUBE_VNET_NAME..."
    az network vnet create  --address-prefixes "10.0.0.0/20"  -g $KUBE_VNET_GROUP -n $KUBE_VNET_NAME -o none
    az network vnet subnet create -g $KUBE_VNET_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_FW_SUBNET_NAME --address-prefix 10.0.3.0/24  -o none
    az network vnet subnet create -g $KUBE_VNET_GROUP --vnet-name $KUBE_VNET_NAME -n $APPGW_SUBNET_NAME --address-prefix 10.0.2.0/24  -o none
    az network vnet subnet create -g $KUBE_VNET_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_ING_SUBNET_NAME --address-prefix 10.0.4.0/24  -o none
    az network vnet subnet create -g $KUBE_VNET_GROUP --vnet-name $KUBE_VNET_NAME -n $MASTERS_SUBNET_NAME --address-prefix 10.0.5.0/24 --disable-private-link-service-network-policies true --service-endpoints Microsoft.ContainerRegistry  -o none
    az network vnet subnet create -g $KUBE_VNET_GROUP --vnet-name $KUBE_VNET_NAME -n $WORKERS_SUBNET_NAME --address-prefix 10.0.8.0/24  --service-endpoints Microsoft.ContainerRegistry  -o none

    VNET_RESOURCE_ID=$(az network vnet show -g $KUBE_VNET_GROUP -n $KUBE_VNET_NAME --query id -o tsv)

    az role assignment create --role "Contributor" --assignee $sp_app_id --scope $VNET_RESOURCE_ID -o none

    echo "created $VNET_RESOURCE_ID"
else
    echo "vnet $VNET_RESOURCE_ID already exists"
fi


MASTERS_SUBNET_ID=$(az network vnet subnet show -g $KUBE_VNET_GROUP --vnet-name $KUBE_VNET_NAME -n $MASTERS_SUBNET_NAME --query id -o tsv)
WORKERS_SUBNET_ID=$(az network vnet subnet show -g $KUBE_VNET_GROUP --vnet-name $KUBE_VNET_NAME -n $WORKERS_SUBNET_NAME --query id -o tsv)

VNET_RESOURCE_ID="/subscriptions/5abd8123-18f8-427f-a4ae-30bfb82617e5/resourceGroups/aro/providers/Microsoft.Network/virtualNetworks/arorunning-vnet"
MASTERS_SUBNET_ID="/subscriptions/5abd8123-18f8-427f-a4ae-30bfb82617e5/resourceGroups/aro/providers/Microsoft.Network/virtualNetworks/arorunning-vnet/subnets/masters-5-subnet"
WORKERS_SUBNET_ID="/subscriptions/5abd8123-18f8-427f-a4ae-30bfb82617e5/resourceGroups/aro/providers/Microsoft.Network/virtualNetworks/arorunning-vnet/subnets/workers-8-subnet"

master_vm_size="Standard_D8s_v3"
worker_vm_size="Standard_D4s_v3"
worker_vm_count=3
pod_cidr="10.128.0.0/14"
service_cidr="172.30.0.0/16"

# The '(z)' trick for the variable flags is something zsh specific
echo "Creating ARO cluster, this is going to take some minutes..."
az aro create -n $cluster_name -g $ARO_GROUP --worker-subnet $WORKERS_SUBNET_ID --master-subnet $MASTERS_SUBNET_ID --vnet $VNET_RESOURCE_ID \
  --master-vm-size $master_vm_size --worker-vm-size $worker_vm_size --worker-count $worker_vm_count \
  --worker-vm-disk-size-gb 128 \
  --client-id $sp_app_id --client-secret $sp_app_secret \
  --ingress-visibility Public --apiserver-visibility Public \
  --tags sampletag1=value1 sampletag2=value2 \
  --cluster-resource-group $INFRA_RG \
  --pod-cidr $pod_cidr --service-cidr $service_cidr --domain running-code.de --pull-secret $pull_secret -o none


dns_zone_name=running-code.de
dns_subdomain=aro
dns_console_hostname=console-openshift-console.apps
dns_oauth_hostname=oauth-openshift.apps
dns_api_hostname=api
# dns_zone_rg=$(az network dns zone list --query "[?name=='$dns_zone_name'].resourceGroup" -o tsv)
# aro_api_ip=$(az aro show -n $cluster_name -g $rg --query 'apiserverProfile.ip' -o tsv)
# aro_ingress_ip=$(az aro show -n $cluster_name -g $rg --query 'ingressProfiles[0].ip' -o tsv)
dns_zone_rg=appconfig
aro_api_ip="20.107.212.126"
aro_ingress_ip="20.123.4.139"

dns_console_fqdn=$dns_console_hostname.$dns_subdomain.$dns_zone_name
dns_oauth_fqdn=$dns_oauth_hostname.$dns_subdomain.$dns_zone_name
dns_api_fqdn=$dns_api_hostname.$dns_subdomain.$dns_zone_name
echo "Adding A record $dns_console_fqdn for IP $aro_ingress_ip"
az network dns record-set a delete -z $dns_zone_name -g $dns_zone_rg -n $dns_console_hostname.$dns_subdomain -y
az network dns record-set a add-record -z $dns_zone_name -g $dns_zone_rg -n $dns_console_hostname.$dns_subdomain -a $aro_ingress_ip
echo "Adding A record $dns_api_fqdn for IP $aro_api_ip"
az network dns record-set a delete -z $dns_zone_name -g $dns_zone_rg -n $dns_api_hostname.$dns_subdomain -y
az network dns record-set a add-record -z $dns_zone_name -g $dns_zone_rg -n $dns_api_hostname.$dns_subdomain -a $aro_api_ip
echo "Adding A record $dns_oauth_fqdn for IP $aro_ingress_ip"
az network dns record-set a delete -z $dns_zone_name -g $dns_zone_rg -n $dns_oauth_hostname.$dns_subdomain -y
az network dns record-set a add-record -z $dns_zone_name -g $dns_zone_rg -n $dns_oauth_hostname.$dns_subdomain -a $aro_ingress_ip
nslookup $dns_console_fqdn
nslookup $dns_oauth_fqdn
nslookup $dns_api_fqdn
# Verify records
az network dns record-set list -z $dns_zone_name -g $dns_zone_rg -o table
echo "A records for $dns_api_fqdn:"
az network dns record-set a show -z $dns_zone_name -g $dns_zone_rg -n $dns_api_hostname.$dns_subdomain --query arecords -o table
echo "A records for $dns_console_fqdn:"
az network dns record-set a show -z $dns_zone_name -g $dns_zone_rg -n $dns_console_hostname.$dns_subdomain --query arecords -o table
echo "A records for $dns_oauth_fqdn"
az network dns record-set a show -z $dns_zone_name -g $dns_zone_rg -n $dns_oauth_hostname.$dns_subdomain --query arecords -o table



# az aro list-credentials -n $cluster_name -g $rg
aro_usr=$(az aro list-credentials -n $cluster_name -g $rg --query kubeadminUsername -o tsv)
aro_pwd=$(az aro list-credentials -n $cluster_name -g $rg --query kubeadminPassword -o tsv)
aro_api_url=$(az aro show -n $cluster_name -g $rg --query 'apiserverProfile.url' -o tsv)
oc login $aro_api_url -u $aro_usr -p $aro_pwd
# echo "Login with the command \"oc login $aro_api_url -u $aro_usr -p $aro_pwd\""
# oc login $aro_api_url -u $aro_usr -p $aro_pwd --insecure-skip-tls-verify=true
# echo "$aro_usr / $aro_pwd"

# Console
aro_console_url=$(az aro show -n $cluster_name -g $rg --query 'consoleProfile.url' -o tsv)
echo "Connect to $aro_console_url (username kubeadmin, password $aro_pwd)"


# Create pods
project_name=kuard
oc new-project $project_name
oc new-app --docker-image gcr.io/kuar-demo/kuard-amd64:1
# Expose with clusterIP and router
oc expose deploy kuard-amd64 --port 8080 --name kuard
oc expose svc kuard --name kuard
# Expose with an internal ALB
oc expose dc kuard-amd64 --port 8080 --type=LoadBalancer --name=kuardilb --dry-run -o yaml | awk '1;/metadata:/{ print "  annotations:\n    service.beta.kubernetes.io/azure-load-balancer-internal: \"true\"" }' | oc create -f -
# Expose with an internal ALB in different subnet
ilb_subnet_name=apps
oc expose dc kuard-amd64 --port 8080 --type=LoadBalancer --name=kuard --dry-run -o yaml | awk '1;/metadata:/{ print "  annotations:\n    service.beta.kubernetes.io/azure-load-balancer-internal: \"true\"\n    service.beta.kubernetes.io/azure-load-balancer-internal-subnet: \"'${ilb_subnet_name}'\"" }' | oc create -f -
# Exposing existing ClusterIP Svc over a route
oc expose svc kuardilb
# Expose with a public ALB
oc expose deploy kuard-amd64 --port 80 --type=LoadBalancer --name=kuardplb


# Deploy CA
# https://docs.openshift.com/container-platform/4.7/machine_management/applying-autoscaling.html
cat <<EOF | kubectl apply -f -
apiVersion: "autoscaling.openshift.io/v1"
kind: "ClusterAutoscaler"
metadata:
    name: "default"
    namespace: "openshift-machine-api"
spec:
    podPriorityThreshold: -10
    resourceLimits:
        maxNodesTotal: 12
    scaleDown:
        enabled: true
        delayAfterAdd: 10s
        delayAfterDelete: 10s
        delayAfterFailure: 10s
EOF
oc get clusterautoscaler -n openshift-machine-api
oc describe clusterautoscaler -n openshift-machine-api

echo "setting up azure monitor"

WORKSPACE_RESOURCE_ID=$(az monitor log-analytics workspace list --resource-group $ARO_GROUP --query "[?contains(name, '$KUBE_NAME')].id" -o tsv)
if [ "$WORKSPACE_RESOURCE_ID" == "" ]; then
    echo "creating workspace $KUBE_NAME in $ARO_GROUP"
    az monitor log-analytics workspace create --resource-group $ARO_GROUP --workspace-name $KUBE_NAME --location $LOCATION -o none
    WORKSPACE_RESOURCE_ID=$(az monitor log-analytics workspace show --resource-group $KUBE_GROUP --workspace-name $KUBE_NAME -o json | jq '.id' -r)

    az role assignment create --assignee $OMS_CLIENT_ID --scope $AKS_ID --role "Monitoring Metrics Publisher"
    
fi
