# Limit administrative access
https://github.com/kubernetes/dashboard/wiki/Creating-sample-user 

create user
```
cat <<EOF | kubectl create -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: metrics-user
  namespace: kube-system
EOF

cat <<EOF | kubectl create -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: dennis
  namespace: kube-system
EOF
```

create cluster role binding
```
cat <<EOF | kubectl create -f -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kube-system
EOF


cat <<EOF | kubectl create -f -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: admin
subjects:
- kind: ServiceAccount
  name: metrics-user
  namespace: kube-system
EOF

cat <<EOF | kubectl create -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: dennis-nodes-get
rules:
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "list"]
EOF

cat <<EOF | kubectl create -f -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: dennis
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: dennis-nodes-get
subjects:
- kind: ServiceAccount
  name: dennis
  namespace: kube-system
EOF

```

after 1.8
```
cat <<EOF | kubectl create -f -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: my-dashboard-sa
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: my-dashboard-sa
  namespace: kube-system
EOF

cat <<EOF | kubectl create -f -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: dennis-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: dennis
  namespace: kube-system
EOF
```

create bearer token
```
kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep edit-user | awk '{print $1}')

kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep dennis | awk '{print $1}')

kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep my-dashboard-sa | awk '{print $1}')
```

Set kubectl context
```

KUBE_MANAGEMENT_ENDPOINT=https://**.azmk8s.io:443
TOKEN=
kubectl config set-cluster dennis-user --server=$KUBE_MANAGEMENT_ENDPOINT --insecure-skip-tls-verify=true

kubectl config set-credentials dennis --token=$TOKEN

kubectl config set-context dennis-context --cluster=dennis-user --user=dennis

kubectl config use-context dennis-context

AzureDiagnostics
| where Category == "kube-apiserver"
| project log_s
AzureDiagnostics
| where Category == "kube-controller-manager"
| project log_s
AzureDiagnostics
| where Category == "kube-scheduler"
| project log_s
AzureDiagnostics
| where Category == "kube-audit"
| project log_s
AzureDiagnostics
| where Category == "guard"
| project log_s
AzureDiagnostics
| where Category == "cluster-autoscaler"
| project log_s
```

## Lock down api server
https://github.com/Azure/azure-cli-extensions/tree/master/src/aks-preview#enable-apiserver-authorized-ip-ranges

MYIP=$(curl ipinfo.io/ip)

KUBE_GROUP="kubvmss"
KUBE_NAME="dzkubvmss"

az aks update -g $KUBE_GROUP  -n $KUBE_NAME --api-server-authorized-ip-ranges "$MYIP"

az aks list -g $KUBE_GROUP -n $KUBE_NAME

## Minimum roles

https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles
```
First-party SPN Permissions
The following permissions are required by the AKS 1st party SPN; The AKS 1st party SPN performs a linked access check on the Cluster creator's role permissions. These permissions are required for CRUD operations on the cluster.

The following permissions are required:

// Required to configure NSG for the subnet when using custom VNET
// AKS property: properties.agentPoolProfiles[*].vnetSubnetID
"Microsoft.Network/virtualNetworks/subnets/join/action"

// Required to allow create, update Log Analytics workspaces and Azure monitoring for Containers
// AKS property: properties.addonProfiles.omsagent.config.logAnalyticsWorkspaceResourceID
"Microsoft.OperationalInsights/workspaces/sharedkeys/read"
"Microsoft.OperationalInsights/workspaces/read"
"Microsoft.OperationsManagement/solutions/write"
"Microsoft.OperationsManagement/solutions/read"

// Required to configure SLB outbound public IPs
// AKS property: properties.networkProfile.loadBalancerProfile.outboundIPs.publicIPs[].ID
// properties.networkProfile.loadBalancerProfile.outboundIPPrefixes.publicIPPrefixes[].ID
"Microsoft.Network/publicIPAddresses/join/action"
"Microsoft.Network/publicIPPrefixes/join/action"

User Permissions
What permissions does a User need to have in order to deploy or perform CRUD operations to AKS. These should be the linked access check permissions cross-checked from the 1st party RP SPN.

See the detailed permissions required in the above section.

AKS SPN Permissions
Validate what permissions are required to be given to the AKS Service Principal (used by Kubernetes cloud provider, volume drivers as well as addons).

Required permissions for AKS SPN
// Required to create, delete or update LoadBalancer for LoadBalancer service
Microsoft.Network/loadBalancers/delete
Microsoft.Network/loadBalancers/read
Microsoft.Network/loadBalancers/write

// Required to allow query, create or delete public IPs for LoadBalancer service
Microsoft.Network/publicIPAddresses/delete
Microsoft.Network/publicIPAddresses/read
Microsoft.Network/publicIPAddresses/write

// Required if public IPs from another resource group are used for LoadBalancer service
// This is because of the linked access check when adding the public IP to LB frontendIPConfiguration
Microsoft.Network/publicIPAddresses/join/action

// Required to create or delete security rules for LoadBalancer service
Microsoft.Network/networkSecurityGroups/read
Microsoft.Network/networkSecurityGroups/write

// Required to create, delete or update AzureDisks
Microsoft.Compute/disks/delete
Microsoft.Compute/disks/read
Microsoft.Compute/disks/write
Microsoft.Compute/locations/DiskOperations/read

// Required to create, update or delete storage accounts for AzureFile or AzureDisk
Microsoft.Storage/storageAccounts/delete
Microsoft.Storage/storageAccounts/listKeys/action
Microsoft.Storage/storageAccounts/read
Microsoft.Storage/storageAccounts/write
Microsoft.Storage/operations/read

// Required to create, delete or update routeTables and routes for nodes
Microsoft.Network/routeTables/read
Microsoft.Network/routeTables/routes/delete
Microsoft.Network/routeTables/routes/read
Microsoft.Network/routeTables/routes/write
Microsoft.Network/routeTables/write

// Required to query information for VM (e.g. zones, faultdomain, size and data disks)
Microsoft.Compute/virtualMachines/read

// Required to attach AzureDisks to VM
Microsoft.Compute/virtualMachines/write

// Required to query information for vmssVM (e.g. zones, faultdomain, size and data disks)
Microsoft.Compute/virtualMachineScaleSets/read
Microsoft.Compute/virtualMachineScaleSets/virtualMachines/read
Microsoft.Compute/virtualMachineScaleSets/virtualmachines/instanceView/read

// Requred to add VM to LoadBalancer backendAddressPools
Microsoft.Network/networkInterfaces/write
// Required to add vmss to LoadBalancer backendAddressPools
Microsoft.Compute/virtualMachineScaleSets/write
// Required to attach AzureDisks and add vmssVM to LB
Microsoft.Compute/virtualMachineScaleSets/virtualmachines/write
// Required to upgrade VMSS models to latest for all instances
// only needed for Kubernetes 1.11.0-1.11.9, 1.12.0-1.12.8, 1.13.0-1.13.5, 1.14.0-1.14.1
Microsoft.Compute/virtualMachineScaleSets/manualupgrade/action

// Required to query internal IPs and loadBalancerBackendAddressPools for VM
Microsoft.Network/networkInterfaces/read
// Required to query internal IPs and loadBalancerBackendAddressPools for vmssVM
microsoft.Compute/virtualMachineScaleSets/virtualMachines/networkInterfaces/read
// Required to get public IPs for vmssVM
Microsoft.Compute/virtualMachineScaleSets/virtualMachines/networkInterfaces/ipconfigurations/publicipaddresses/read

// Required to check whether subnet existing for ILB in another resource group
Microsoft.Network/virtualNetworks/read
Microsoft.Network/virtualNetworks/subnets/read

// Required to create, update or delete snapshots for AzureDisk
Microsoft.Compute/snapshots/delete
Microsoft.Compute/snapshots/read
Microsoft.Compute/snapshots/write

// Required to get vm sizes for getting AzureDisk volume limit
Microsoft.Compute/locations/vmSizes/read
Microsoft.Compute/locations/operations/read
Permissions users "might" need
When using container insights, the following permissions are required

// Required to allow create, update Log Analytics workspaces and Azure monitoring for Containers.
// Refer https://docs.microsoft.com/en-us/azure/azure-monitor/insights/container-insights-update-metrics#upgrade-per-cluster-using-azure-cli.
"Monitoring Metrics Publisher" or Microsoft.Insights/Metrics/Write

When using public IP addresses in another resource group,

// Required to allow query or create public IPs for LoadBalancer service
Microsoft.Network/publicIPAddresses/read
Microsoft.Network/publicIPAddresses/write
Microsoft.Network/publicIPAddresses/join/action
When using NSG in another resource group,

// Required to create or delete security rules for LoadBalancer service
Microsoft.Network/networkSecurityGroups/read
Microsoft.Network/networkSecurityGroups/write
When using subnet in another resource group (e.g. custom VNET),

// Required to check whether subnet existing for subnet in another resource group
Microsoft.Network/virtualNetworks/subnets/read
Microsoft.Network/virtualNetworks/subnets/join/action
When using ILB for another resource group,

// Required to check whether subnet existing for ILB in another resource group
Microsoft.Network/virtualNetworks/subnets/read
```

## Use dashboard with azure ad
https://gist.github.com/digeler/0dbc40141c9ee8a41b42e808a2859f14

turn on the dashboard
```
az aks enable-addons --addons kube-dashboard -g $KUBE_GROUP -n $KUBE_NAME
```

turn off the dashboard
```
az aks disable-addons --addons kube-dashboard -g $KUBE_GROUP -n $KUBE_NAME
```

edit the deployment of the dashboard
```
kubectl edit deployments kubernetes-dashboard -n kube-system
```

containers:
- name: kubernetes-dashboard
  args:
  - --authentication-mode=token
  - --enable-insecure-login


## Create SSH Box

```
kubectl run -it aks-ssh --image=debian

apt-get update && apt-get install openssh-client -y

kubectl cp ~/.ssh/id_rsa $(kubectl get pod -l run=aks-ssh -o jsonpath='{.items[0].metadata.name}'):/id_rsa

chmod 400 ~/.ssh/id_rsa

ssh -i id_rsa dennis@10.0.5.4

sudo add-apt-repository ppa:wireshark-dev/stable
sudo apt-get update
sudo apt-get install wireshark
sudo apt install tshark
sudo dpkg-reconfigure wireshark-common
sudo usermod -a -G wireshark dennis

tshark -Q -i2 -O http -T json tcp port 7001 | grep http.file_data
```

## Auditing

```
{"kind":"Event","apiVersion":"audit.k8s.io/v1","level":"Request","auditID":"130ba120-d9b1-4b35-9e91-3366568bfd8d","stage":"ResponseComplete","requestURI":"/api/v1/namespaces/default/pods/nginx","verb":"get","user":{"username":"masterclient","groups":["system:masters","system:authenticated"]},"sourceIPs":["52.191.253.156"],"userAgent":"kubectl/v1.14.0 (linux/amd64) kubernetes/641856d","objectRef":{"resource":"pods","namespace":"default","name":"nginx","apiVersion":"v1"},"responseStatus":{"metadata":{},"status":"Failure","reason":"NotFound","code":404},"requestReceivedTimestamp":"2019-09-20T11:52:19.062985Z","stageTimestamp":"2019-09-20T11:52:19.068391Z","annotations":{"authorization.k8s.io/decision":"allow","authorization.k8s.io/reason":""}}

 

{"kind":"Event","apiVersion":"audit.k8s.io/v1","level":"Request","auditID":"e13ca54f-9b7a-4a47-abb4-930d0b518c49","stage":"ResponseComplete","requestURI":"/api/v1/namespaces/default/pods/nginx/status","verb":"patch","user":{"username":"nodeclient","groups":["system:nodes","system:authenticated"]},"sourceIPs":["13.88.18.92"],"userAgent":"kubelet/v1.14.5 (linux/amd64) kubernetes/0e9fcb4","objectRef":{"resource":"pods","namespace":"default","name":"nginx","apiVersion":"v1","subresource":"status"},"responseStatus":{"metadata":{},"code":200},"requestObject":{"status":{"$setElementOrder/conditions":[{"type":"Initialized"},{"type":"Ready"},{"type":"ContainersReady"},{"type":"PodScheduled"}],"conditions":[{"lastTransitionTime":"2019-09-20T12:56:55Z","message":null,"reason":null,"status":"True","type":"Ready"},{"lastTransitionTime":"2019-09-20T12:56:55Z","message":null,"reason":null,"status":"True","type":"ContainersReady"}],"containerStatuses":[{"containerID":"docker://e4d6babb34b671237490bbf384326c142281bcabe0c74416ea63088146ed1500","image":"nginx:1.15.5","imageID":"docker-pullable://nginx@sha256:b73f527d86e3461fd652f62cf47e7b375196063bbbd503e853af5be16597cb2e","lastState":{},"name":"mypod","ready":true,"restartCount":0,"state":{"running":{"startedAt":"2019-09-20T12:56:55Z"}}}],"phase":"Running","podIP":"10.244.4.11"}},"requestReceivedTimestamp":"2019-09-20T12:56:55.895345Z","stageTimestamp":"2019-09-20T12:56:55.910588Z","annotations":{"authorization.k8s.io/decision":"allow","authorization.k8s.io/reason":"RBAC: allowed by ClusterRoleBinding \"system:aks-client-nodes\" of ClusterRole \"system:node\" to Group \"system:nodes\""}}
```

## Kubernetes API

create service account
```
kubectl create serviceaccount centos

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: demo
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: centos
  namespace: demo
---
apiVersion: v1
kind: Pod
metadata:
  name: centos
  namespace: demo
spec:
  serviceAccountName: centos
  containers:
  - name: centoss
    image: centos
    ports:
    - containerPort: 80
    command:
    - sleep
    - "3600"
EOF
```


```

kubectl exec -ti centos -n demo -- /bin/bash

cat /var/run/secrets/kubernetes.io/serviceaccount/token

KUBE_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)

echo $KUBERNETES_SERVICE_HOST
10.96.0.1

echo $KUBERNETES_PORT_443_TCP_PORT
443

echo $HOSTNAME
centos

curl -sSk -H "Authorization: Bearer $KUBE_TOKEN" https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_PORT_443_TCP_PORT/api/v1/namespaces/demo/pods

curl -H "Authorization: Bearer $KUBE_TOKEN" https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_PORT_443_TCP_PORT/api/v1 --insecure

curl -H "Authorization: Bearer $KUBE_TOKEN" https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_PORT_443_TCP_PORT/api/v1/nodes --insecure

kubectl create clusterrolebinding demo-admin --clusterrole cluster-admin --serviceaccount=demo:centos


```

create service account role binding
```

cat <<EOF | kubectl apply -f -
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: pods-list
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["list"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: pods-list
subjects:
- kind: ServiceAccount
  name: centos
  namespace: demo
roleRef:
  kind: ClusterRole
  name: pods-list
  apiGroup: rbac.authorization.k8s.io
EOF
```


cleanup 
```

kubectl delete ClusterRoleBinding pods-list
kubectl delete ClusterRole pods-list
kubectl delete pod centos -n demo
kubectl delete serviceaccount centos -n demo
kubectl delete ns demo
```


# Security Center
List of AKS features for Security Center:
https://docs.microsoft.com/en-gb/azure/security-center/security-center-alerts-compute#aks-cluster-level-alerts

```
SUBSCRIPTION_ID=
open https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Security/assessmentMetadata?api-version=2019-01-01-preview
```


# Create service account

```

KUBE_GROUP="dzprivate1"
KUBE_NAME="dzprivate1"

kubectl create serviceaccount jump-account --namespace kube-system
kubectl create clusterrolebinding jump-account-binding --clusterrole=cluster-admin --serviceaccount=kube-system:jump-account --namespace kube-system

kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep jump-account | awk '{print $1}')

KUBE_MANAGEMENT_ENDPOINT=https://**.azmk8s.io:443
TOKEN=
kubectl config set-cluster dennis-user --server=$KUBE_MANAGEMENT_ENDPOINT --insecure-skip-tls-verify=true

kubectl config set-credentials dennis --token=$TOKEN

kubectl config set-context dennis-context --cluster=dennis-user --user=dennis

kubectl config use-context dennis-context

az aks command invoke --resource-group $KUBE_GROUP --name $KUBE_NAME --command "kubectl get pods -n kube-system"

```