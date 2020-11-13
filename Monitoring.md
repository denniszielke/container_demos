# deploy demo apps

```
DEMO_NS=demo


export CRASHING_APP_IP=$(kubectl get svc --namespace $DEMO_NS crashing-app -o jsonpath='{.status.loadBalancer.ingress[0].ip}')


export DUMMY_LOGGER_IP=$(kubectl get svc --namespace $DEMO_NS dummy-logger-svc-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}')


curl -X POST http://$DUMMY_LOGGER_IP/api/log -H "message: {more: content}" 
curl -X POST http://$DUMMY_LOGGER_IP/api/log -H "message: hi" 

curl -X GET http://$CRASHING_APP_IP/crash
```

Built in issue detection
https://docs.microsoft.com/en-gb/azure/azure-monitor/insights/container-insights-analyze?toc=%2Fazure%2Fmonitoring%2Ftoc.json#view-performance-directly-from-an-aks-cluster

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

helm upgrade --install loki -n=monitoring loki/loki-stack --set grafana.enabled=true,prometheus.enabled=true,prometheus.alertmanager.persistentVolume.enabled=true,prometheus.server.persistentVolume.enabled=true

helm upgrade --install promtail -n=monitoring promtail/promtail

kubectl get secret --namespace monitoring loki-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
kubectl port-forward --namespace monitoring service/loki-grafana 3000:80