# Deploy the OMS (AKS)

https://docs.microsoft.com/en-us/azure/aks/tutorial-kubernetes-monitor
https://docs.microsoft.com/en-us/azure/log-analytics/log-analytics-containers 
https://docs.microsoft.com/en-gb/azure/monitoring/media/monitoring-container-insights-overview/azmon-containers-views.png

## Deploy the secrets

0. Define variables

```
WORKSPACE_ID=
WORKSPACE_KEY=
```

1. Deploy the oms daemons

get the latest yaml file from here
https://github.com/Microsoft/OMS-docker/blob/master/Kubernetes/omsagent.yaml 
https://github.com/Microsoft/OMS-docker/blob/ci_feature_prod/Kubernetes/omsagent.yaml

```
kubectl create -f https://raw.githubusercontent.com/denniszielke/container_demos/master/logging/omsdaemonset.yaml
kubectl get daemonset
```

Deploy cluster role for live log streaming
```
cat <<EOF | kubectl apply -f -
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1 
metadata:
  name: containerHealth-log-reader
rules:
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1 
metadata:
  name: containerHealth-read-logs-global
subjects:
  - kind: User
    name: clusterUser
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: containerHealth-log-reader
  apiGroup: rbac.authorization.k8s.io
EOF
```

## Create custom logs via dummy logger

1. Create host to log from dummy logger
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

LOGGER_IP=

kubectl get svc dummy-logger -o template --template "{{(index .items 0).status.loadBalancer.ingress }}"

curl -H "message: hallo" -X POST http://$LOGGER_IP/api/log
```

See the response
```
kubectl logs dummy-logger
{"timestamp":"2018-09-21 06:39:44","value":37,"host":"dummy-logger","source":"::ffff:10.0.4.97","message":"hi"}%    
```

3. Search for the log message in log analytics by this query
https://docs.microsoft.com/en-us/azure/monitoring/monitoring-container-insights-analyze?toc=%2fazure%2fmonitoring%2ftoc.json#example-log-search-queries

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

let startDateTime = datetime('2018-10-22T06:15:00.000Z');
let endDateTime = datetime('2018-10-22T12:26:21.322Z');
let ContainerIdList = KubePodInventory              
| where TimeGenerated >= startDateTime and TimeGenerated < endDateTime              
| where ContainerName startswith 'buggy-app'              
| where ClusterName =~ "dkubaci"                            
| distinct ContainerID;            
ContainerLog            
| where TimeGenerated >= startDateTime and TimeGenerated < endDateTime            
| where ContainerID in (ContainerIdList)            
| project LogEntrySource, LogEntry, TimeGenerated, Computer, Image, Name, ContainerID            
| order by TimeGenerated desc            
| render table


let startTimestamp = ago(1d);
KubePodInventory
    | where TimeGenerated > startTimestamp
    | where ClusterName =~ "dkubaci"
    | distinct ContainerID
| join
(
  ContainerLog
  | where TimeGenerated > startTimestamp
)
on ContainerID
  | project LogEntrySource, LogEntry, TimeGenerated, Computer, Image, Name, ContainerID
  | order by TimeGenerated desc
  | render table

Perf 
| where ObjectName == "Container" and CounterName == "Memory Usage MB"
| where InstanceName contains "buggy-app" 
| summarize AvgUsedMemory = avg(CounterValue) by bin(TimeGenerated, 30m), InstanceName

Perf
| where ObjectName == "Container" and CounterName == "% Processor Time"
| where InstanceName contains "buggy-app" 
| summarize AvgCPUPercent = avg(CounterValue) by bin(TimeGenerated, 30m), InstanceName

You will see raw data from your log output

4. Create a custom log format
https://docs.microsoft.com/en-us/azure/log-analytics/log-analytics-data-sources-custom-logs 
Goto Log Analytics -> Data -> Custom Logs

Upload this file:



Cleanup
```
kubectl delete pod,svc dummy-logger
```

## Logging on pod crashes

```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: buggy-app
  labels:
    app: buggy-app
spec:
  containers:
    - name: buggy-app
      image: denniszielke/buggy-app:latest
      livenessProbe:
        httpGet:
          path: /ping
          port: 80
          scheme: HTTP
        initialDelaySeconds: 20
        timeoutSeconds: 5
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
  name: buggy-app
  namespace: default
spec:
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: buggy-app
  type: LoadBalancer
EOF
```

```
cat <<EOF | kubectl apply -f -
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: buggy-app
spec:
  replicas: 1
  minReadySeconds: 5
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
  template:
    metadata:
      labels:
        name: buggy-app
        demo: logging
        app: buggy-app
    spec:
      containers:
      - name: buggy-app
        image: denniszielke/buggy-app:latest
        livenessProbe:
          httpGet:
            path: /ping
            port: 80
            scheme: HTTP
          initialDelaySeconds: 20
          timeoutSeconds: 5
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
  name: buggy-app
  namespace: default
spec:
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: buggy-app
  type: LoadBalancer
EOF
```

deploy crashing app
```
cat <<EOF | kubectl apply -f -
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: crashing-app
spec:
  replicas: 1
  minReadySeconds: 5
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
  template:
    metadata:
      labels:
        name: crashing-app
        demo: logging
        app: crashing-app
    spec:
      containers:
      - name: crashing-app
        image: denniszielke/crashing-app:latest
        livenessProbe:
          httpGet:
            path: /ping
            port: 80
            scheme: HTTP
          initialDelaySeconds: 20
          timeoutSeconds: 5
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
  name: crashing-app
  namespace: default
spec:
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: crashing-app
  type: LoadBalancer
EOF
```

## Create an alert based on container fail

Log query
```
ContainerInventory
| where Image contains "buggy-app" and CreatedTime > ago(10m) and ContainerState == "Failed"
| summarize AggregatedValue = dcount(ContainerID) by Computer, Image, ContainerState
```

ContainerInventory | where Image contains "buggy-app" and CreatedTime > ago(10m) and ContainerState == "Failed"

## Log nginx http errors

```
cat <<EOF | kubectl apply -f - 
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: hello-world-ingress
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - host: 13.80.244.73.xip.io
    http:
      paths:
      - path: /
        backend:
          serviceName: aks-helloworld
          servicePort: 80
      - path: /buggy
        backend:
          serviceName: dummy-logger
          servicePort: 80
      - path: /web
        backend:
          serviceName: nginx
          servicePort: 80
EOF
```

## Logging from ACI

```
LOCATION=westeurope
ACI_GROUP=aci-group

az container create --image denniszielke/dummy-logger --resource-group $ACI_GROUP --location $LOCATION --name dummy-logger --os-type Linux --cpu 1 --memory 3.5 --dns-name-label dummy-logger --ip-address public --ports 80 --verbose

LOGGER_IP=
LOGGER_IP=
LEAKER_IP=
CRASHER_IP=

curl -H "message: hi" -X POST http://$LOGGER_IP/api/log

curl -X GET http://$CRASHER_IP/crash

curl -X GET http://$LEAKER_IP/leak

for i in `seq 1 20`; do time curl -s $LEAKER_IP/leak > /dev/null; done
```