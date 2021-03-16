KUBE_NAME=$1
KUBE_GROUP=$2

AZURE_TENANT_ID=$(az account show --query tenantId -o tsv)
SUBSCRIPTION_ID=$(az account show --query id -o tsv) #subscriptionid
LOCATION=$(az group show -n $KUBE_GROUP --query location -o tsv)
NODE_GROUP=$(az aks show --resource-group $KUBE_GROUP --name $KUBE_NAME --query nodeResourceGroup -o tsv)


SERVICE_PRINCIPAL_ID=$(az ad sp show --id $KUBE_NAME -o json | jq -r '.[0].appId')
if [ "$SERVICE_PRINCIPAL_ID" == "" ]; then
   SERVICE_PRINCIPAL_ID=$(az ad sp create-for-rbac --skip-assignment --name $KUBE_NAME -o json | jq -r '.appId')
fi

SERVICE_PRINCIPAL_SECRET=$(az ad app credential reset --append --id $SERVICE_PRINCIPAL_ID -o json | jq '.password' -r)

echo -e "\n\n Remember these outputs:"
echo -e "Your Kubernetes service_principal_id should be \e[7m$SERVICE_PRINCIPAL_ID\e[0m"
echo -e "Your Kubernetes service_principal_secret should be \e[7m$SERVICE_PRINCIPAL_SECRET\e[0m"
echo -e "Your Azure tenant_id should be \e[7m$AZURE_TENANT_ID\e[0m"
echo -e "Your Azure subscription_id should be \e[7m$SUBSCRIPTION_ID\e[0m"
echo -e "\n\n"

az role assignment create --role "Reader" --assignee $SERVICE_PRINCIPAL_ID -g $KUBE_GROUP -o none

WORKSPACE_RESOURCE_ID=$(az monitor log-analytics workspace list --resource-group $KUBE_GROUP --query "[?contains(name, '$KUBE_NAME-lga')].id" -o tsv)

az role assignment create --role "Log Analytics Reader" --assignee $SERVICE_PRINCIPAL_ID --scope $WORKSPACE_RESOURCE_ID -o none



kubectl create namespace monitoring

helm repo add prometheus https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install po \
  --namespace monitoring \
  prometheus/kube-prometheus-stack --wait


helm repo add loki https://grafana.github.io/loki/charts
helm repo update
helm upgrade --install loki \
  --namespace monitoring \
  loki/loki --wait
#--set grafana.enabled=true,prometheus.enabled=true,prometheus.alertmanager.persistentVolume.enabled=true,prometheus.server.persistentVolume.enabled=true

helm upgrade --install promtail \
  --namespace monitoring \
  --set loki.serviceName=loki \
  loki/promtail --wait


kubectl port-forward deployment/po-grafana 3000 3000 -n monitoring
#UserName: admin
#Password: prom-operator
#URL: http://loki:3100


# import https://grafana.com/grafana/dashboards/10956

# import api server https://grafana.com/grafana/dashboards/12006