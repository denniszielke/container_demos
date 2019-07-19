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

## Filter oms agent data collection
https://docs.microsoft.com/en-us/azure/azure-monitor/insights/container-insights-agent-config

.\HealthAgentOnboarding.ps1 -aksResourceId /subscriptions/5abd8123-18f8-427f-a4ae-30bfb82617e5/resourcegroups/kub_ter_a_m_scale38/providers/Microsoft.ContainerService/managedClusters/scale38 -aksResourceLocation westeurope -logAnalyticsWorkspaceResourceId /subscriptions/5abd8123-18f8-427f-a4ae-30bfb82617e5/resourcegroups/kub_ter_a_m_scale38/providers/microsoft.operationalinsights/workspaces/scale38-lga

az storage account create --resource-group  MC_kub_ter_a_m_scale38_scale38_westeurope --name dzscalelogs --location westeurope --sku Standard_LRS

echo "
apiVersion: v1
kind: ServiceAccount
metadata:
  name: omsagent
  namespace: kube-system
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: omsagent-reader
rules:
- apiGroups: [""]
  resources: ["pods", "events", "nodes", "namespaces", "services"]
  verbs: ["list", "get", "watch"]
- apiGroups: ["extensions"]
  resources: ["deployments"]
  verbs: ["list"]
- nonResourceURLs: ["/metrics"]
  verbs: ["get"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: omsagentclusterrolebinding
subjects:
  - kind: ServiceAccount
    name: omsagent
    namespace: kube-system
roleRef:
  kind: ClusterRole
  name: omsagent-reader
  apiGroup: rbac.authorization.k8s.io
---
kind: ConfigMap
apiVersion: v1
data:
  kube.conf: |-
     # Fluentd config file for OMS Docker - cluster components (kubeAPI)
     #fluent forward plugin
     <source>
      type forward
      port 25235
      bind 0.0.0.0
     </source>

     #Kubernetes pod inventory
     <source>
      type kubepodinventory
      tag oms.containerinsights.KubePodInventory
      run_interval 60s
      log_level debug
     </source>

     #Kubernetes events
     <source>
      type kubeevents
      tag oms.containerinsights.KubeEvents
      run_interval 60s
      log_level debug
      </source>

     #Kubernetes logs
     <source>
      type kubelogs
      tag oms.api.KubeLogs
      run_interval 60s
     </source>

     #Kubernetes services
     <source>
      type kubeservices
      tag oms.containerinsights.KubeServices
      run_interval 60s
      log_level debug
     </source>

     #Kubernetes Nodes
     <source>
      type kubenodeinventory
      tag oms.containerinsights.KubeNodeInventory
      run_interval 60s
      log_level debug
     </source>

     #Kubernetes perf
     <source>
      type kubeperf
      tag oms.api.KubePerf
      run_interval 60s
      log_level debug
     </source>

     #Kubernetes health
     <source>
      type kubehealth
      tag oms.api.KubeHealth.ReplicaSet
      run_interval 60s
      log_level debug
     </source>

     #cadvisor perf- Windows nodes
     <source>
      type wincadvisorperf
      tag oms.api.wincadvisorperf
      run_interval 60s
      log_level debug
     </source>

     <filter mdm.kubepodinventory** mdm.kubenodeinventory**>
      type filter_inventory2mdm
      custom_metrics_azure_regions eastus,southcentralus,westcentralus,westus2,southeastasia,northeurope,westEurope
      log_level info
     </filter>

     # custom_metrics_mdm filter plugin for perf data from windows nodes
     <filter mdm.cadvisorperf**>
      type filter_cadvisor2mdm
      custom_metrics_azure_regions eastus,southcentralus,westcentralus,westus2,southeastasia,northeurope,westEurope
      metrics_to_collect cpuUsageNanoCores,memoryWorkingSetBytes
      log_level info
     </filter>
     #health model aggregation filter
     <filter oms.api.KubeHealth**>
      type filter_health_model_builder
     </filter>

     <match oms.containerinsights.KubePodInventory**>
      type out_oms
      log_level debug
      num_threads 5
      buffer_chunk_limit 20m
      buffer_type file
      buffer_path %STATE_DIR_WS%/out_oms_kubepods*.buffer
      buffer_queue_limit 20
      buffer_queue_full_action drop_oldest_chunk
      flush_interval 20s
      retry_limit 10
      retry_wait 30s
      max_retry_wait 9m
     </match>

     <match oms.containerinsights.KubeEvents**>
      type out_oms
      log_level debug
      num_threads 5
      buffer_chunk_limit 5m
      buffer_type file
      buffer_path %STATE_DIR_WS%/out_oms_kubeevents*.buffer
      buffer_queue_limit 10
      buffer_queue_full_action drop_oldest_chunk
      flush_interval 20s
      retry_limit 10
      retry_wait 30s
      max_retry_wait 9m
     </match>

     <match oms.api.KubeLogs**>
      type out_oms_api
      log_level debug
      buffer_chunk_limit 10m
      buffer_type file
      buffer_path %STATE_DIR_WS%/out_oms_api_kubernetes_logs*.buffer
      buffer_queue_limit 10
      flush_interval 20s
      retry_limit 10
      retry_wait 30s
     </match>

     <match oms.containerinsights.KubeServices**>
      type out_oms
      log_level debug
      num_threads 5
      buffer_chunk_limit 20m
      buffer_type file
      buffer_path %STATE_DIR_WS%/out_oms_kubeservices*.buffer
      buffer_queue_limit 20
      buffer_queue_full_action drop_oldest_chunk
      flush_interval 20s
      retry_limit 10
      retry_wait 30s
      max_retry_wait 9m
     </match>

     <match oms.containerinsights.KubeNodeInventory**>
      type out_oms
      log_level debug
      num_threads 5
      buffer_chunk_limit 20m
      buffer_type file
      buffer_path %STATE_DIR_WS%/state/out_oms_kubenodes*.buffer
      buffer_queue_limit 20
      buffer_queue_full_action drop_oldest_chunk
      flush_interval 20s
      retry_limit 10
      retry_wait 30s
      max_retry_wait 9m
     </match>

     <match oms.containerinsights.ContainerNodeInventory**>
      type out_oms
      log_level debug
      buffer_chunk_limit 20m
      buffer_type file
      buffer_path %STATE_DIR_WS%/out_oms_containernodeinventory*.buffer
      buffer_queue_limit 20
      flush_interval 20s
      retry_limit 10
      retry_wait 15s
      max_retry_wait 9m
     </match>

     <match oms.api.KubePerf**>
      type out_oms
      log_level debug
      num_threads 5
      buffer_chunk_limit 20m
      buffer_type file
      buffer_path %STATE_DIR_WS%/out_oms_kubeperf*.buffer
      buffer_queue_limit 20
      buffer_queue_full_action drop_oldest_chunk
      flush_interval 20s
      retry_limit 10
      retry_wait 30s
      max_retry_wait 9m
     </match>

     <match mdm.kubepodinventory** mdm.kubenodeinventory** >
      type out_mdm
      log_level debug
      num_threads 5
      buffer_chunk_limit 20m
      buffer_type file
      buffer_path %STATE_DIR_WS%/out_mdm_*.buffer
      buffer_queue_limit 20
      buffer_queue_full_action drop_oldest_chunk
      flush_interval 20s
      retry_limit 10
      retry_wait 30s
      max_retry_wait 9m
      retry_mdm_post_wait_minutes 60
     </match>

     <match oms.api.wincadvisorperf**>
      type out_oms
      log_level debug
      num_threads 5
      buffer_chunk_limit 20m
      buffer_type file
      buffer_path %STATE_DIR_WS%/out_oms_api_wincadvisorperf*.buffer
      buffer_queue_limit 20
      buffer_queue_full_action drop_oldest_chunk
      flush_interval 20s
      retry_limit 10
      retry_wait 30s
      max_retry_wait 9m
     </match>

     <match mdm.cadvisorperf**>
      type out_mdm
      log_level debug
      num_threads 5
      buffer_chunk_limit 20m
      buffer_type file
      buffer_path %STATE_DIR_WS%/out_mdm_cdvisorperf*.buffer
      buffer_queue_limit 20
      buffer_queue_full_action drop_oldest_chunk
      flush_interval 20s
      retry_limit 10
      retry_wait 30s
      max_retry_wait 9m
      retry_mdm_post_wait_minutes 60
     </match>

     <match oms.api.KubeHealth.AgentCollectionTime**>
      type out_oms_api
      log_level debug
      buffer_chunk_limit 10m
      buffer_type file
      buffer_path %STATE_DIR_WS%/out_oms_api_kubehealth*.buffer
      buffer_queue_limit 10
      flush_interval 20s
      retry_limit 10
      retry_wait 30s
     </match>
metadata:
  name: omsagent-rs-config
  namespace: kube-system
---
apiVersion: v1
kind: Secret
metadata:
 name: omsagent-secret
 namespace: kube-system
type: Opaque
data:
  WSID: "ZmIwMTUxMmMtZTJhMS00N2YyLTk1YjYtMTlmM2MzMmI4Y2E0"
  KEY: "SWZzUTBQdDlMWjRzSjRKQU9IWWM3UzRXSFhWT1F3alNOY0dmb3BJeWxHZmFDanNVVlZPNjFlbUk2L0FuNTh1RTJxOTE3Uk5sNU5nWWltSmNUVktmTXc9PQ=="
---
kind: Service
apiVersion: v1
metadata:
  name: replicaset-service
  namespace: kube-system
spec:
  selector:
    rsName: "omsagent-rs"
  ports:
  - protocol: TCP
    port: 25235
    targetPort: in-rs-tcp
---
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: azurefile
provisioner: kubernetes.io/azure-file
mountOptions:
  - dir_mode=0777
  - file_mode=0777
  - uid=1000
  - gid=1000
parameters:
  skuName: Standard_LRS
  storageAccount: dzscalelogs
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: system:azure-cloud-provider
rules:
- apiGroups: ['']
  resources: ['secrets']
  verbs:     ['get','create']
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: system:azure-cloud-provider
roleRef:
  kind: ClusterRole
  apiGroup: rbac.authorization.k8s.io
  name: system:azure-cloud-provider
subjects:
- kind: ServiceAccount
  name: persistent-volume-binder
  namespace: kube-system
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: azurefile
  namespace: kube-system
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: azurefile
  resources:
    requests:
      storage: 10Mi
---

echo "
apiVersion: extensions/v1beta1
kind: DaemonSet
metadata:
 name: omsagent
 namespace: kube-system
spec:
 updateStrategy:
  type: RollingUpdate
 template:
  metadata:
   labels:
    dsName: "omsagent-ds"
   annotations:
    agentVersion: "1.10.0.1"
    dockerProviderVersion: "5.0.0-1"
    schema-versions: "v1"
  spec:
   serviceAccountName: omsagent
   containers:
     - name: omsagent
       image: "mcr.microsoft.com/azuremonitor/containerinsights/ciprod:healthpreview07182019"
       imagePullPolicy: IfNotPresent
       resources:
        limits:
         cpu: 150m
         memory: 300Mi
        requests:
         cpu: 75m
         memory: 225Mi
       env:
       - name: AKS_RESOURCE_ID
         value: "/subscriptions/5abd8123-18f8-427f-a4ae-30bfb82617e5/resourcegroups/kub_ter_a_m_scale38/providers/Microsoft.ContainerService/managedClusters/scale38"
       - name: AKS_REGION
         value: "westeurope"
       - name: DISABLE_KUBE_SYSTEM_LOG_COLLECTION
         value: "true"
       - name: CONTROLLER_TYPE
         value: "DaemonSet"
       - name: NODE_IP
         valueFrom:
            fieldRef:
              fieldPath: status.hostIP
       securityContext:
         privileged: true
       ports:
       - containerPort: 25225
         protocol: TCP
       - containerPort: 25224
         protocol: UDP
       volumeMounts:
        - mountPath: /hostfs
          name: host-root
          readOnly: true
        - mountPath: /var/run/host
          name: docker-sock
        - mountPath: /var/log
          name: host-log
        - mountPath: /var/lib/docker/containers
          name: containerlog-path
        - mountPath: /etc/kubernetes/host
          name: azure-json-path
        - mountPath: /etc/omsagent-secret
          name: omsagent-secret
        - mountPath: /etc/config/settings
          name: settings-vol-config
          readOnly: true
       livenessProbe:
        exec:
         command:
         - /bin/bash
         - -c
         - /opt/livenessprobe.sh
        initialDelaySeconds: 60
        periodSeconds: 60
   nodeSelector:
    beta.kubernetes.io/os: linux
   tolerations:
    - key: "node-role.kubernetes.io/master"
      operator: "Equal"
      value: "true"
      effect: "NoSchedule"
   volumes:
    - name: host-root
      hostPath:
       path: /
    - name: docker-sock
      hostPath:
       path: /var/run
    - name: container-hostname
      hostPath:
       path: /etc/hostname
    - name: host-log
      hostPath:
       path: /var/log
    - name: containerlog-path
      hostPath:
       path: /var/lib/docker/containers
    - name: azure-json-path
      hostPath:
       path: /etc/kubernetes
    - name: omsagent-secret
      secret:
       secretName: omsagent-secret
    - name: settings-vol-config
      configMap:
        name: container-azm-ms-agentconfig
        optional: true
---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
 name: omsagent-rs
 namespace: kube-system
spec:
 replicas: 1
 selector:
  matchLabels:
   rsName: "omsagent-rs"
 strategy:
  type: RollingUpdate
 template:
  metadata:
   labels:
    rsName: "omsagent-rs"
   annotations:
    agentVersion: "1.10.0.1"
    dockerProviderVersion: "5.0.0-1"
    schema-versions: "v1"
  spec:
   serviceAccountName: omsagent
   containers:
     - name: omsagent
       image: "mcr.microsoft.com/azuremonitor/containerinsights/ciprod:healthpreview07182019"
       imagePullPolicy: IfNotPresent
       resources:
        limits:
         cpu: 150m
         memory: 500Mi
        requests:
         cpu: 50m
         memory: 175Mi
       env:
       - name: AKS_RESOURCE_ID
         value: "/subscriptions/5abd8123-18f8-427f-a4ae-30bfb82617e5/resourcegroups/kub_ter_a_m_scale38/providers/Microsoft.ContainerService/managedClusters/scale38"
       - name: AKS_REGION
         value: "westeurope"
       - name: DISABLE_KUBE_SYSTEM_LOG_COLLECTION
         value: "true"
       - name: CONTROLLER_TYPE
         value: "ReplicaSet"
       - name: NODE_IP
         valueFrom:
            fieldRef:
              fieldPath: status.hostIP
       securityContext:
         privileged: true
       ports:
       - containerPort: 25225
         protocol: TCP
       - containerPort: 25224
         protocol: UDP
       - containerPort: 25235
         protocol: TCP
         name: in-rs-tcp
       volumeMounts:
        - mountPath: /var/run/host
          name: docker-sock
        - mountPath: /var/log
          name: host-log
        - mountPath: /var/lib/docker/containers
          name: containerlog-path
        - mountPath: /etc/kubernetes/host
          name: azure-json-path
        - mountPath: /etc/omsagent-secret
          name: omsagent-secret
          readOnly: true
        - mountPath : /etc/config
          name: omsagent-rs-config
        - mountPath: /etc/config/settings
          name: settings-vol-config
          readOnly: true
        - mountPath: "/mnt/azure"
          name: azurefile-pv
       livenessProbe:
        exec:
         command:
         - /bin/bash
         - -c
         - ps -ef | grep omsagent | grep -v "grep"
        initialDelaySeconds: 60
        periodSeconds: 60
   nodeSelector:
    beta.kubernetes.io/os: linux
    kubernetes.io/role: agent
   volumes:
    - name: docker-sock
      hostPath:
       path: /var/run
    - name: container-hostname
      hostPath:
       path: /etc/hostname
    - name: host-log
      hostPath:
       path: /var/log
    - name: containerlog-path
      hostPath:
       path: /var/lib/docker/containers
    - name: azure-json-path
      hostPath:
       path: /etc/kubernetes
    - name: omsagent-secret
      secret:
       secretName: omsagent-secret
    - name: omsagent-rs-config
      configMap:
        name: omsagent-rs-config
    - name: settings-vol-config
      configMap:
        name: container-azm-ms-agentconfig
        optional: true
    - name: azurefile-pv
      persistentVolumeClaim:
        claimName: azurefile
" | kubectl apply -f -