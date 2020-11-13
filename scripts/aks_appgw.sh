APPGW_NAME="dzappgw5"
APPGW_GROUP="kub_ter_a_m_appgw5" # here enter the appgw resource group name
APPGW_SUBNET_NAME="gw-1-subnet" # name of AppGW subnet
VNET="appgw5-vnet"

APPGW_SUBNET_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$APPGW_GROUP/providers/Microsoft.Network/virtualNetworks/$VNET/subnets/$APPGW_SUBNET_NAME"
az network public-ip create --resource-group $APPGW_GROUP --name $APPGW_NAME-pip --allocation-method Static --sku Standard
APPGW_PUBLIC_IP=$(az network public-ip show -g $APPGW_GROUP -n $APPGW_NAME-pip --query ipAddress -o tsv)
az network application-gateway create --name $APPGW_NAME --resource-group $APPGW_GROUP --location $LOCATION --http2 Enabled --min-capacity 0 --max-capacity 10 --sku WAF_v2  --vnet-name $VNET --subnet $APPGW_SUBNET_ID --http-settings-cookie-based-affinity Disabled --frontend-port 80 --http-settings-port 80 --http-settings-protocol Http --public-ip-address $APPGW_NAME-pip --private-ip-address "10.0.1.100"
APPGW_NAME=$(az network application-gateway list --resource-group=$APPGW_GROUP -o json | jq -r ".[0].name")
APPGW_RESOURCE_ID=$(az network application-gateway list --resource-group=$APPGW_GROUP -o json | jq -r ".[0].id")
APPGW_SUBNET_ID=$(az network application-gateway list --resource-group=$APPGW_GROUP -o json | jq -r ".[0].gatewayIpConfigurations[0].subnet.id")

KUBELET_ID=$(az aks show -g $KUBE_GROUP -n $KUBE_NAME --query identityProfile.kubeletidentity.clientId -o tsv)
CONTROLLER_ID=$(az aks show -g $KUBE_GROUP -n $KUBE_NAME --query identity.principalId -o tsv)
NODE_GROUP=$(az aks show --resource-group $KUBE_GROUP --name $KUBE_NAME --query nodeResourceGroup -o tsv)

az role assignment create --role "Managed Identity Operator" --assignee $KUBELET_ID --scope /subscriptions/$SUBSCRIPTION_ID/resourcegroups/$NODE_GROUP
az role assignment create --role "Managed Identity Operator" --assignee $CONTROLLER_ID --scope /subscriptions/$SUBSCRIPTION_ID/resourcegroups/$NODE_GROUP
az role assignment create --role "Virtual Machine Contributor" --assignee $KUBELET_ID --scope /subscriptions/$SUBSCRIPTION_ID/resourcegroups/$NODE_GROUP
az role assignment create --role "Reader" --assignee $KUBELET_ID --scope /subscriptions/$SUBSCRIPTION_ID/resourcegroups/$KUBE_GROUP

az identity create -g $NODE_GROUP -n $APPGW_NAME-id
sleep 5 # wait for replication
AGIC_ID_CLIENT_ID="$(az identity show -g $NODE_GROUP -n $APPGW_NAME-id  --query clientId -o tsv)"
AGIC_ID_RESOURCE_ID="$(az identity show -g $NODE_GROUP -n $APPGW_NAME-id  --query id -o tsv)"

NODES_RESOURCE_ID=$(az group show -n $NODE_GROUP -o tsv --query "id")
KUBE_GROUP_RESOURCE_ID=$(az group show -n $KUBE_GROUP -o tsv --query "id")
sleep 15 # wait for replication
echo "assigning permissions for AGIC client $AGIC_ID_CLIENT_ID"
az role assignment create --role "Contributor" --assignee $AGIC_ID_CLIENT_ID --scope $APPGW_RESOURCE_ID
az role assignment create --role "Reader" --assignee $AGIC_ID_CLIENT_ID --scope $KUBE_GROUP_RESOURCE_ID # might not be needed
az role assignment create --role "Reader" --assignee $AGIC_ID_CLIENT_ID --scope $NODES_RESOURCE_ID # might not be needed
az role assignment create --role "Reader" --assignee $AGIC_ID_CLIENT_ID --scope /subscriptions/$SUBSCRIPTION_ID/resourcegroups/$APPGW_GROUP

helm repo add application-gateway-kubernetes-ingress https://appgwingress.blob.core.windows.net/ingress-azure-helm-package/
helm repo update

helm pull application-gateway-kubernetes-ingress/ingress-azure

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
     --set verbosityLevel=3 
    # --set kubernetes.watchNamespace=default


cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1alpha2
kind: ClusterIssuer
metadata:
  name: letsencrypt
  namespace: kube-system
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: $MY_USER_ID
    privateKeySecretRef:
      name: letsencrypt-secret
    solvers:
    - http01:
        ingress:
          class: azure/application-gateway
EOF    


az aks enable-addons --resource-group $KUBE_GROUP --name $KUBE_NAME  -a ingress-appgw --appgw-id $APPGW_RESOURCE_ID


kubectl apply -f https://raw.githubusercontent.com/Azure/application-gateway-kubernetes-ingress/master/docs/examples/aspnetapp.yaml 
