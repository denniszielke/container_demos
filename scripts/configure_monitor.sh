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

#az role assignment create --role "Monitoring Reader" --assignee $SERVICE_PRINCIPAL_ID --scope /subscriptions/$SUBSCRIPTION_ID -o none
#az role assignment create --role "Reader" --assignee $SERVICE_PRINCIPAL_ID --scope /subscriptions/$SUBSCRIPTION_ID -o none

WORKSPACE_RESOURCE_ID=$(az monitor log-analytics workspace list --resource-group $KUBE_GROUP --query "[?contains(name, '$KUBE_NAME')].id" -o tsv)

az role assignment create --role "Log Analytics Reader" --assignee $SERVICE_PRINCIPAL_ID --scope $WORKSPACE_RESOURCE_ID -o none

OMS_CLIENT_ID=$(az aks show -g $KUBE_GROUP -n $KUBE_NAME --query addonProfiles.omsagent.identity.clientId -o tsv)
AKS_ID=$(az aks show -g $KUBE_GROUP -n $KUBE_NAME --query id -o tsv)
if [ "$OMS_CLIENT_ID" == "" ]; then
    az aks enable-addons --resource-group $KUBE_GROUP --name $KUBE_NAME --addons monitoring --workspace-resource-id $WORKSPACE_RESOURCE_ID
    az role assignment create --assignee $OMS_CLIENT_ID --scope $AKS_ID --role "Monitoring Metrics Publisher"
else
  az role assignment create --assignee $OMS_CLIENT_ID --scope $AKS_ID --role "Monitoring Metrics Publisher"
fi

curl -skSL https://raw.githubusercontent.com/kubernetes-sigs/azurefile-csi-driver/master/deploy/install-driver.sh | bash -s master --

kubectl create -f https://raw.githubusercontent.com/kubernetes-sigs/azurefile-csi-driver/master/deploy/example/storageclass-azurefile-csi.yaml
kubectl create -f https://raw.githubusercontent.com/kubernetes-sigs/azurefile-csi-driver/master/deploy/example/storageclass-azurefile-nfs.yaml

## contributor on nodes 
## contributor on aks subnet for service endpoint

helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
kubectl create namespace monitoring

helm upgrade --install loki grafana/loki-stack -n monitoring  --set grafana.enabled=true,grafana.persistence.enabled=true,grafana.persistence.storageClassName=azurefile-csi-nfs,prometheus.enabled=true,prometheus.alertmanager.persistentVolume.enabled=false,prometheus.server.persistentVolume.enabled=false,loki.persistence.enabled=true,loki.persistence.storageClassName=azurefile-csi,loki.persistence.size=5Gi


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


kubectl port-forward deployment/loki-grafana 3000 3000 -n monitoring
# kubectl get secret -n monitoring loki-grafana -o jsonpath="{.data.admin-password}" | base64 --decode

#UserName: admin
#Password: prom-operator
#URL: http://loki:3100

# import https://grafana.com/grafana/dashboards/10956

# import api server https://grafana.com/grafana/dashboards/12006

DNS=dzgrafana1.westeurope.cloudapp.azure.com

for i in {1..10000}; do curl -X POST -s -w "%{time_total}\n" -o /dev/null http://$DNS/api/log -H "message: {more: content}"; sleep 0.5; curl -X POST http://$DNS/api/log -H "message: hi" ; done

while(true); do sleep 0.5; curl -X POST http://$DNS/api/log -H "message: {more: content}" ; curl -X POST http://$DNS/api/log -H "message: hi" ;  done
