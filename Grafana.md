# Grafana

kubectl -n monitoring port-forward $(kubectl -n monitoring get \
  pod -l app=grafana -o jsonpath='{.items[0].metadata.name}') 3000:3000 &



https://www.stefanroth.net/2019/10/18/azure-monitor-helm-install-aks-monitoring-grafana-dashboard-with-azure-ad-integration/