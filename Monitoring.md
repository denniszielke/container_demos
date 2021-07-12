# deploy demo apps

```
DEMO_NS=demo


export CRASHING_APP_IP=$(kubectl get svc --namespace $DEMO_NS crashing-app -o jsonpath='{.status.loadBalancer.ingress[0].ip}')


export DUMMY_LOGGER_IP=$(kubectl get svc --namespace $DEMO_NS dummy-logger-svc-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
export DUMMY_LOGGER_IP=$(kubectl get svc dummy-logger-pub-lb  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

curl -X POST http://$DUMMY_LOGGER_IP/api/log -H "message: {more: content}" 
curl -X POST http://$DUMMY_LOGGER_IP/api/log -H "message: hi" 

curl -X GET http://$CRASHING_APP_IP/crash
```

Built in issue detection
https://docs.microsoft.com/en-gb/azure/azure-monitor/insights/container-insights-analyze?toc=%2Fazure%2Fmonitoring%2Ftoc.json#view-performance-directly-from-an-aks-cluster

az role assignment create --assignee 88cf3744-9ed9-4d55-a563-e027e7f8687f --scope /subscriptions/$SUBSCRIPTION_ID/resourcegroups/$KUBE_GROUP/providers/Microsoft.ContainerService/managedClusters/$KUBE_NAME --role "Monitoring Metrics Publisher"

# cluster health
https://docs.microsoft.com/en-us/azure/azure-monitor/insights/container-insights-health

# coredns 
```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns-custom
  namespace: kube-system
data:
  log.override: |
        log
EOF
```

```
InsightsMetrics 
| where Namespace contains "prometheus"
| where TimeGenerated > ago(1h)
| where Name startswith "coredns_"
| summarize max(Val) by Name, bin(TimeGenerated, 1m)
| render timechart

InsightsMetrics 
| where Namespace contains "prometheus"
| where TimeGenerated > ago(1h)
| where Name == "coredns_forward_request_duration_seconds" or Name == "coredns_dns_request_duration_seconds" 
| summarize max(Val) by Name, bin(TimeGenerated, 1m)
| render timechart
```

## Full stack

```
kubectl create namespace monitoring

helm repo add prometheus-operator https://kubernetes-charts.storage.googleapis.com
helm repo add loki https://grafana.github.io/loki/charts
helm repo add promtail https://grafana.github.io/loki/charts


helm repo update
helm upgrade --install po  prometheus-operator/prometheus-operator -n=monitoring

helm upgrade --install loki -n=monitoring loki/loki-stack --set grafana.enabled=true,prometheus.enabled=true,prometheus.alertmanager.persistentVolume.enabled=true,prometheus.server.persistentVolume.enabled=true,persistence.enabled=true

helm upgrade --install promtail -n=monitoring promtail/promtail

kubectl get secret --namespace monitoring loki-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
kubectl port-forward --namespace monitoring service/loki-grafana 3000:80

```

## Loki
https://github.com/grafana/helm-charts/blob/main/charts/grafana/README.md


```
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```


## Troubleshooting Logs

```
KUBE_NAME=
LOCATION=westeurope
KUBE_GROUP=kub_ter_a_m_$KUBE_NAME
KUBE_VERSION=1.19.7

az rest --method get --url "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$KUBE_GROUP/providers/Microsoft.
OperationalInsights/workspaces/$KUBE_NAME-lga/tables/ContainerLog?api-version=2020-10-01"

az rest --method get --url "https://management.azure.com/subscriptions/5abd8123-18f8-427f-a4ae-30bfb82617e5/resourceGroups/dzcheapobs/providers/Microsoft.OperationalInsights/workspaces/dzcheapobs/tables/ContainerLog?api-version=2020-10-01"

{

  "name": "ContainerLog",
  "properties": {
    "isTroubleshootingAllowed": true,
    "isTroubleshootEnabled": true,
    "retentionInDays": 30
  },
}

az rest --method put --url "https://management.azure.com/subscriptions/5abd8123-18f8-427f-a4ae-30bfb82617e5/resourceGroups/dzcheapobs/providers/Microsoft.OperationalInsights/workspaces/dzcheapobs/tables/ContainerLog?api-version=2020-10-01" --body @container_log.json


wget https://raw.githubusercontent.com/microsoft/Docker-Provider/ci_prod/kubernetes/container-azm-ms-agentconfig.yaml

```

## API Server Statistics

Requests per minute by VERB

| where PreciseTimeStamp >= datetime({startTime}) and PreciseTimeStamp < datetime({endTime}) | where resourceID == 

| where category == 'kube-audit'

| extend event=parse_json(tostring(parse_json(properties).log))

| where event.stage == "ResponseComplete"

| where event.verb != "watch"

| where event.objectRef.subresource !in ("proxy", "exec")

| extend verb=tostring(event.verb)

| extend subresource=tostring(event.objectRef.subresource)

| summarize count() by bin(PreciseTimeStamp, 1m), verb


Request latency per VERB

| where PreciseTimeStamp >= datetime({startTime}) and PreciseTimeStamp < datetime({endTime})

| where resourceID == <<Customer cluster resourceID >>


AzureDiagnostics
| where category == 'kube-audit'
| extend event=parse_json(tostring(parse_json(properties).log))
| where event.stage == "ResponseComplete"
| where event.verb != "watch"
| where event.objectRef.subresource !in ("proxy", "exec")
| extend verb=tostring(event.verb)
| extend subresource=tostring(event.objectRef.subresource)
| extend latency=datetime_diff('Millisecond', todatetime(event.stageTimestamp), todatetime(event.requestReceivedTimestamp))
| summarize max(latency), avg(latency) by bin(PreciseTimeStamp, 1m), verb


Number of watchers

| where PreciseTimeStamp >= datetime({startTime}) and PreciseTimeStamp < datetime({endTime})

| where resourceID == <<Customer cluster resourceID >>

AzureDiagnostics
| where category == 'kube-audit'
| extend event=parse_json(tostring(parse_json(properties).log))
| where event.stage == "ResponseComplete"
| where event.verb != "watch"
| where event.objectRef.subresource !in ("proxy", "exec")
| extend verb=tostring(event.verb)
| extend code=tostring(event.responseStatus.code)
| extend subresource=tostring(event.objectRef.subresource)
| extend lat=datetime_diff('Millisecond', todatetime(event.stageTimestamp), todatetime(event.requestReceivedTimestamp))
| summarize count() by bin(PreciseTimeStamp, 1m), code