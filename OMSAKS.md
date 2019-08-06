# Deploy the OMS (AKS)

https://docs.microsoft.com/en-us/azure/aks/tutorial-kubernetes-monitor
https://docs.microsoft.com/en-us/azure/log-analytics/log-analytics-containers 
https://docs.microsoft.com/en-gb/azure/monitoring/media/monitoring-container-insights-overview/azmon-containers-views.png
https://github.com/helm/charts/tree/master/incubator/azuremonitor-containers


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

get oms agent version
```
kubectl get pods -l component=oms-agent -o yaml -n kube-system | grep image:
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
          cpu: "100m"
        limits:
          memory: "256Mi"
          cpu: "200m"
---
apiVersion: v1
kind: Service
metadata:
  name: dummy-logger
  namespace: default
  #annotations:
  #  service.beta.kubernetes.io/azure-load-balancer-internal: "true"
  #  service.beta.kubernetes.io/azure-load-balancer-internal-subnet: "ing-4-subnet"
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

```
let startDateTime = datetime('2018-10-22T06:15:00.000Z');
let endDateTime = datetime('2019-10-22T12:26:21.322Z');
let ContainerIdList = KubePodInventory              
| where TimeGenerated >= startDateTime and TimeGenerated < endDateTime              
| where ContainerName startswith 'crashing-app'              
| where ClusterName =~ "mesh44"                            
| distinct ContainerID;            
ContainerLog            
| where TimeGenerated >= startDateTime and TimeGenerated < endDateTime            
| where ContainerID in (ContainerIdList)            
| project LogEntrySource, LogEntry, TimeGenerated, Computer, Image, Name, ContainerID            
| order by TimeGenerated desc            
| render table
```

```
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
```
You will see raw data from your log output

4. Create a custom log format
https://docs.microsoft.com/en-us/azure/log-analytics/log-analytics-data-sources-custom-logs 
Goto Log Analytics -> Data -> Custom Logs


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

```
cat <<EOF | kubectl apply -f -
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: dummy-logger
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
        name: dummy-logger
        demo: logging
        app: dummy-logger
    spec:
      containers:
      - name: dummy-logger
        image: denniszielke/dummy-logger:latest
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
  name: dummy-logger
  namespace: default
spec:
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: dummy-logger
  type: ClusterIP
EOF
```

## Create an alert based on container fail

Log query
```
ContainerInventory
| where Image contains "buggy-app" and TimeGenerated > ago(10m) and ContainerState == "Failed"
| summarize AggregatedValue = dcount(ContainerID) by Computer, Image, ContainerState
```

```
ContainerInventory | where Image contains "buggy-app" and TimeGenerated > ago(10m) and ContainerState == "Failed"
```

## Crash or leak app

cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1 
kind: ClusterRole 
metadata: 
   name: containerHealth-log-reader 
rules: 
   - apiGroups: [""] 
     resources: ["pods/log", "events"] 
     verbs: ["get", "list"]  
--- 
apiVersion: rbac.authorization.k8s.io/v1 
kind: ClusterRoleBinding 
metadata: 
   name: containerHealth-read-logs-global 
roleRef: 
    kind: ClusterRole 
    name: containerHealth-log-reader 
    apiGroup: rbac.authorization.k8s.io 
subjects: 
   - kind: User 
     name: clusterUser 
     apiGroup: rbac.authorization.k8s.io
EOF

the app has a route called crash - it you call it the app will crash
/crash 

the app has a route called leak - if you call it it will leak memory
/leak

```
LOGGER_IP=40.74.50.209
LOGGER_IP=10.0.147.7
LEAKER_IP=40.74.50.209
CRASHER_IP=52.233.129.228

curl -H "message: hi" -X POST http://$LOGGER_IP/api/log

curl -X GET http://$CRASHER_IP/crash

curl -X GET http://$LOGGER_IP/leak
```

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
  - host: 23.97.165.51.xip.io
    http:
      paths:
      - path: /
        backend:
          serviceName: dummy-logger
          servicePort: 80
EOF
```

curl -k -v -XGET  -H "User-Agent: kubectl/v1.12.2 (darwin/amd64) kubernetes/17c77c7" -H "Accept: application/json;as=Table;v=v1beta1;g=meta.k8s.io, application/json" -H "Authorization: Bearer xxxxx" 'https://acnie-34961d1e.hcp.westeurope.azmk8s.io:443/api/v1/componentstatuses?limit=500'

## Logging from ACI

```
LOCATION=westeurope
ACI_GROUP=aci-group

az container create --image denniszielke/dummy-logger --resource-group $ACI_GROUP --location $LOCATION --name dummy-logger --os-type Linux --cpu 1 --memory 3.5 --dns-name-label dummy-logger --ip-address public --ports 80 --verbose

LOGGER_IP=40.115.24.237
LOGGER_IP=40.68.132.153
LEAKER_IP=40.115.24.237
CRASHER_IP=40.115.24.237

curl -H "message: hi" -X POST http://$LOGGER_IP/api/log

curl -X GET http://$CRASHER_IP/crash

curl -X GET http://$CRASHER_IP/leak

for i in `seq 1 20`; do time curl -s $LEAKER_IP/leak > /dev/null; done
```
