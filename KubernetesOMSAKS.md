# Deploy the OMS (AKS)

https://docs.microsoft.com/en-us/azure/aks/tutorial-kubernetes-monitor
https://docs.microsoft.com/en-us/azure/log-analytics/log-analytics-containers 

## Deploy the secrets

0. Define variables

```
WORKSPACE_ID=
WORKSPACE_KEY=
```

1. Deploy the oms daemons

get the latest yaml file from here
https://github.com/Microsoft/OMS-docker/blob/master/Kubernetes/omsagent.yaml 

```
kubectl create -f https://raw.githubusercontent.com/denniszielke/container_demos/master/logging/omsdaemonset.yaml
kubectl get daemonset
```

## Create custom logs

1. Create host to log from
```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: dummy-logger
  labels:
    app: dummy-logger
spec:
  containers:
    - name: dummy-logger
      image: denniszielke/dummy-logger:latest
      ports:
        - containerPort: 80
          name: http
          protocol: TCP
      imagePullPolicy: Always   
      resources:
        requests:
          memory: "128Mi"
          cpu: "500m"
        limits:
          memory: "256Mi"
          cpu: "1000m"
---
apiVersion: v1
kind: Service
metadata:
  name: dummy-logger
  namespace: default
spec:
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: dummy-logger
  type: LoadBalancer
EOF
```

2. Figure out ip and log something
```
kubectl get svc,pod dummy-logger

LOGGER_IP=13.93.65.225

kubectl get svc dummy-logger -o template --template "{{(index .items 0).status.loadBalancer.ingress }}"

curl -H "message: ho" -X POST http://$LOGGER_IP/api/log

```

See the response
```
{"timestamp":"2018-09-21 06:39:44","value":37,"host":"dummy-logger","source":"::ffff:10.0.4.97","message":"hi"}%    
```

3. Search for the log message in log analytics by this query

```
let startTimestamp = ago(1h);
KubePodInventory
| where TimeGenerated > startTimestamp
| where ClusterName =~ "dzkubeaks"
| distinct ContainerID
| join
(
    ContainerLog
    | where TimeGenerated > startTimestamp
)
on ContainerID
| project LogEntrySource, LogEntry, TimeGenerated, Computer, Image, Name, ContainerID
| order by TimeGenerated desc
| where LogEntrySource == "stdout"
| where Image == "dummy-logger"
| render table
```

You will see raw data from your log output

4. Create a custom log format
https://docs.microsoft.com/en-us/azure/log-analytics/log-analytics-data-sources-custom-logs 
Goto Log Analytics -> Data -> Custom Logs

Upload this file:



Cleanup
```
kubectl delete pod,svc dummy-logger
```

## Logging from ACI


LOCATION=westeurope
ACI_GROUP=aci-group

az container create --image denniszielke/dummy-logger --resource-group $ACI_GROUP --location $LOCATION --name dummy-logger --os-type Linux --cpu 1 --memory 3.5 --dns-name-label dummy-logger --ip-address public --ports 80 --verbose

LOGGER_IP=dummy-logger.westeurope.azurecontainer.io

curl -H "message: hi" -X POST http://$LOGGER_IP/api/log
