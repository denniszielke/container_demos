# Grafana

install
```
GRAFANA_IN=my-grafana
GRAFANA_NS=monitoring
kubectl create ns $GRAFANA_NS
helm upgrade --install $GRAFANA_IN stable/grafana --set plugins={grafana-azure-monitor-datasource} --namespace $GRAFANA_NS
```

get secret
```
kubectl get secret -n $GRAFANA_NS $GRAFANA_IN -o jsonpath="{.data.admin-password}" | base64 --decode
```


create port forwarding
```
kubectl port-forward --namespace $GRAFANA_NS service/$GRAFANA_IN 3000:80 &
```

## Configure azure monitor plugin
https://grafana.com/grafana/plugins/grafana-azure-monitor-datasource
https://docs.microsoft.com/en-gb/azure/azure-monitor/platform/grafana-plugin
https://www.stefanroth.net/2019/10/18/azure-monitor-helm-install-aks-monitoring-grafana-dashboard-with-azure-ad-integration/

```
SUBSCRIPTION_ID=""
TENANT_ID=""
SERVICE_PRINCIPAL_ID=""
SERVICE_PRINCIPAL_SECRET=""
```

KUBE_NAME=monitoring71
SUBSCRIPTION_ID=$(az account show --query id -o tsv) # here enter your subscription id

AZURE_TENANT_ID=$(az account show --query tenantId -o tsv)
echo $AZURE_TENANT_ID
SERVICE_PRINCIPAL_ID=$(az ad sp show --id $KUBE_NAME -o json | jq -r '.[0].appId')
echo $SERVICE_PRINCIPAL_ID

SERVICE_PRINCIPAL_SECRET=$(az ad app credential reset --append --id $SERVICE_PRINCIPAL_ID -o json | jq '.password' -r)

echo -e "\n\n Remember these outputs:"
echo -e "Your Kubernetes service_principal_id should be \e[7m$SERVICE_PRINCIPAL_ID\e[0m"
echo -e "Your Kubernetes service_principal_secret should be \e[7m$SERVICE_PRINCIPAL_SECRET\e[0m"
echo -e "Your Azure tenant_id should be \e[7m$AZURE_TENANT_ID\e[0m"
echo -e "Your Azure subscription_id should be \e[7m$SUBSCRIPTION_ID\e[0m"
echo -e "\n\n"


DashboardId
10956


## Loki

install
```
LOKI_IN=my-loki
LOKI_NS=loki
helm repo add loki https://grafana.github.io/loki/charts
helm repo update
kubectl create ns $LOKI_NS
helm upgrade --install $LOKI_IN -n=$LOKI_NS loki/loki-stack --set grafana.enabled=true,prometheus.enabled=true,prometheus.alertmanager.persistentVolume.enabled=false,prometheus.server.persistentVolume.enabled=false
helm -n loki-stack ls
```

connect
```
kubectl get secret --namespace $LOKI_NS $LOKI_IN-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
kubectl port-forward --namespace $LOKI_NS service/$LOKI_IN-grafana 3000:80

```
