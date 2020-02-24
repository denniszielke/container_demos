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

# image inventory
```
ContainerInventory 
| distinct  Repository, Image, ImageTag 
| order by Repository, Image
```

# error types

Events
```
KubeEvents
| where TimeGenerated > ago(1h)
| project Computer, Namespace, Name, Reason, Count
```

Kubelet errors in the last errors
```
let data = InsightsMetrics
| where Origin == 'container.azm.ms/telegraf'
| where TimeGenerated > ago(1h)
| where Namespace == 'container.azm.ms/prometheus'
| where Name == 'kubelet_docker_operations' or Name == 'kubelet_docker_operations_errors'
| extend Tags = todynamic(Tags)
| extend OperationType = tostring(Tags['operation_type']), HostName = tostring(Tags.hostName)
| where '*' in ('*') or HostName in ('*')
| where '*' in ('*') or OperationType in ('*')
| extend partitionKey = strcat(HostName, '/' , Name, '/', OperationType)
| order by partitionKey asc, TimeGenerated asc
| serialize
| extend PrevVal = iif(prev(partitionKey) != partitionKey, 0.0, prev(Val)), PrevTimeGenerated = iif(prev(partitionKey) != partitionKey, datetime(null), prev(TimeGenerated))
| where isnotnull(PrevTimeGenerated) and PrevTimeGenerated != TimeGenerated
| extend Rate = iif(PrevVal > Val, Val, Val - PrevVal)
| where isnotnull(Rate)
| project TimeGenerated, Name, HostName, Rate;
let operationData = data
| where Name == 'kubelet_docker_operations';
let totalOperationsByNode = operationData
| summarize Rate = sum(Rate) by HostName
| project HostName, TotalOperations = Rate;
let totalOperationsByNodeSeries = operationData
| make-series TotalOperationsSeries = sum(Rate) default = 0 on TimeGenerated from ago(21600s) to now() step 10m by HostName
| project-away TimeGenerated;
let errorData = data
| where Name == 'kubelet_docker_operations_errors';
let totalErrorsByNode = errorData
| summarize Rate = sum(Rate) by HostName
| project HostName, TotalErrors = Rate;
let totalErrorsByNodeSeries = errorData
| make-series TotalErrorsSeries = sum(Rate) default = 0 on TimeGenerated from ago(21600s) to now() step 10m by HostName
| project-away TimeGenerated;
totalOperationsByNode
| join kind = leftouter
(
    totalErrorsByNode
)
on HostName
| join kind = leftouter
(
    totalOperationsByNodeSeries
)
on HostName
| join kind = leftouter
(
    totalErrorsByNodeSeries
)
on HostName
| extend TotalErrors = iif(isempty(TotalErrors), 0.0, TotalErrors)
| extend SeriesOfEqualLength = range(1, array_length(TotalOperationsSeries), 1)
| extend SeriesOfZeroes = series_multiply(SeriesOfEqualLength, 0)
| extend TotalErrorsSeries = iif(isempty(TotalErrorsSeries), SeriesOfZeroes, TotalErrorsSeries)
| project-away HostName1, HostName2, HostName3
| extend TotalSuccessfulOperationsSeries = series_subtract(TotalOperationsSeries, TotalErrorsSeries)
| extend IsNegativeTotalSuccessfulOperationsSeries = series_less(TotalSuccessfulOperationsSeries, SeriesOfZeroes)
| extend TotalSuccessfulOperationsSeries = array_iif(IsNegativeTotalSuccessfulOperationsSeries, SeriesOfZeroes, TotalSuccessfulOperationsSeries)
| extend SuccessPercentage = round(iif(TotalOperations == 0, 1.0, iif(TotalErrors > TotalOperations, 0.0, 1 - (TotalErrors / TotalOperations))), 4), SuccessPercentageSeries = series_divide(TotalSuccessfulOperationsSeries, TotalOperationsSeries)
| extend SeriesOfOneHundo = series_multiply(series_divide(SeriesOfEqualLength, SeriesOfEqualLength), 100)
| extend SuccessfulOperationsEqualsTotalOperationsSeries = series_equals(TotalSuccessfulOperationsSeries, TotalOperationsSeries)
| extend SuccessPercentageSeries = array_iff(SuccessfulOperationsEqualsTotalOperationsSeries, SeriesOfOneHundo, SuccessPercentageSeries)
| project HostName, TotalOperations, TotalErrors, SuccessPercentage
| order by SuccessPercentage asc, HostName asc
| project-rename Node = HostName, ['Total Operations'] = TotalOperations, ['Total Errors'] = TotalErrors
```

Kubelet operations by operation type
```
let data = InsightsMetrics
| where Origin == 'container.azm.ms/telegraf'
| where Namespace == 'container.azm.ms/prometheus'
| where Name == 'kubelet_docker_operations' or Name == 'kubelet_docker_operations_errors'
| extend Tags = todynamic(Tags)
| extend OperationType = tostring(Tags['operation_type']), HostName = tostring(Tags.hostName)
| where '*' in ('*') or HostName in ('*')
| where '*' in ('*') or OperationType in ('*')
| extend partitionKey = strcat(HostName, '/' , Name, '/', OperationType)
| order by partitionKey asc, TimeGenerated asc
| serialize
| extend PrevVal = iif(prev(partitionKey) != partitionKey, 0.0, prev(Val)), PrevTimeGenerated = iif(prev(partitionKey) != partitionKey, datetime(null), prev(TimeGenerated))
| where isnotnull(PrevTimeGenerated) and PrevTimeGenerated != TimeGenerated
| extend Rate = iif(PrevVal > Val, Val, Val - PrevVal)
| where isnotnull(Rate)
| project TimeGenerated, Name, OperationType, Rate;
let operationData = data
| where Name == 'kubelet_docker_operations';
let totalOperationsByType = operationData
| summarize Rate = sum(Rate) by OperationType
| project OperationType, TotalOperations = Rate;
let totalOperationsByTypeSeries = operationData
| make-series TotalOperationsByTypeSeries = sum(Rate) default = 0 on TimeGenerated from ago(21600s) to now() step 10m by OperationType
| project-away TimeGenerated;
let errorsData = data
| where Name == 'kubelet_docker_operations_errors';
let totalErrorsByType = errorsData
| summarize Rate = sum(Rate) by OperationType
| project OperationType, TotalErrors = Rate;
let totalErrorsByTypeSeries = errorsData
| make-series TotalErrorsByTypeSeries = sum(Rate) default = 0 on TimeGenerated from ago(21600s) to now() step 10m by OperationType
| project-away TimeGenerated;
let seriesLength = toscalar(   totalOperationsByTypeSeries
| extend ArrayLength = array_length(TotalOperationsByTypeSeries)
| summarize Array_Length = max(ArrayLength)  );
totalOperationsByType
| join kind = leftouter
(
    totalErrorsByType
)
on OperationType
| project-away OperationType1
| extend TotalErrors = iif(isempty(TotalErrors), 0.0, TotalErrors)
| join kind = leftouter
(
    totalErrorsByTypeSeries
)
on OperationType
| project-away OperationType1
| extend SeriesOfEqualLength = range(1, seriesLength, 1)
| extend SeriesOfZeroes = series_subtract(SeriesOfEqualLength, SeriesOfEqualLength)
| extend SeriesOfOneHundo = series_multiply(series_divide(SeriesOfEqualLength, SeriesOfEqualLength), 100)
| extend TotalErrorsByTypeSeries = iif(isempty(TotalErrorsByTypeSeries), SeriesOfZeroes, TotalErrorsByTypeSeries)
| join kind=leftouter
(
    totalOperationsByTypeSeries
)
on OperationType
| project-away OperationType1
| extend TotalSuccessfulOperationsByTypeSeries = series_subtract(TotalOperationsByTypeSeries, TotalErrorsByTypeSeries)
| extend IsNegativeTotalSuccessfulOperationsByTypeSeries = series_less(TotalSuccessfulOperationsByTypeSeries, SeriesOfZeroes)
| extend TotalSuccessfulOperationsByTypeSeries = array_iif(IsNegativeTotalSuccessfulOperationsByTypeSeries, SeriesOfZeroes, TotalSuccessfulOperationsByTypeSeries)
| extend SuccessPercentage = round(iif(TotalOperations == 0, 1.0, iif(TotalErrors > TotalOperations, 0.0, 1 - (TotalErrors / TotalOperations))), 4), SuccessPercentageSeries = series_divide(TotalSuccessfulOperationsByTypeSeries, TotalOperationsByTypeSeries)
| extend SuccessfulOperationsEqualsTotalOperationsSeries = series_equals(TotalSuccessfulOperationsByTypeSeries, TotalOperationsByTypeSeries)
| extend SuccessPercentageSeries = array_iff(SuccessfulOperationsEqualsTotalOperationsSeries, SeriesOfOneHundo, SuccessPercentageSeries)
| project OperationType, TotalOperations, TotalErrors, SuccessPercentage
| order by SuccessPercentage asc, OperationType asc
| project-rename ['Operation Type'] = OperationType, ['Total Operations'] = TotalOperations, ['Total Errors'] = TotalErrors, ['Success %'] = SuccessPercentage
```


## Alerts
https://docs.microsoft.com/bs-latn-ba/azure/azure-monitor/insights/container-insights-alerts


Alert for disc utiluzation
let clusterId = '/subscriptions/5abd8123-18f8-427f-a4ae-30bfb82617e5/resourceGroups/kub_ter_a_m_monitoring71/providers/Microsoft.ContainerService/managedClusters/monitoring71';
let endDateTime = now();
let startDateTime = ago(1h);
let trendBinSize = 1m;
InsightsMetrics
| where TimeGenerated < endDateTime
| where TimeGenerated >= startDateTime
| where Origin == 'container.azm.ms/telegraf'            
| where Namespace == 'container.azm.ms/disk'            
| extend Tags = todynamic(Tags)            
| project TimeGenerated, ClusterId = Tags['container.azm.ms/clusterId'], Computer = tostring(Tags.hostName), Device = tostring(Tags.device), Path = tostring(Tags.path), DiskMetricName = Name, DiskMetricValue = Val   
| where ClusterId =~ clusterId       
| where DiskMetricName == 'used_percent'
| summarize AggregatedValue = max(DiskMetricValue)