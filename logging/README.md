
## Azure Monitor scrape config
https://review.learn.microsoft.com/en-us/azure/azure-monitor/essentials/prometheus-metrics-scrape-configuration?branch=pr-en-us-210933


## Create prometheus config
https://review.learn.microsoft.com/en-us/azure/azure-monitor/essentials/prometheus-metrics-scrape-validate?branch=pr-en-us-210933#apply-config-file

https://github.com/Azure/prometheus-collector/blob/main/otelcollector/configmaps/ama-metrics-prometheus-config-node-windows-configmap.yaml
```

kubectl create configmap ama-metrics-prometheus-config --from-file=prometheus-config -n kube-system
```