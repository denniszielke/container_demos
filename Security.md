# Limit administrative access
https://github.com/kubernetes/dashboard/wiki/Creating-sample-user 

create user
```
cat <<EOF | kubectl create -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
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
  name: dennis
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: admin
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

"Microsoft.Resources/deployments/validate/action",
//Required for ARM preflight validation


"Microsoft.Compute/availabilitySets/read",
"Microsoft.Compute/availabilitySets/write",
"Microsoft.Compute/availabilitySets/delete",
//Required to allow create,write into and delete AS's



"Microsoft.Compute/locations/operations/read",
"Microsoft.Network/locations/operations/read",

// Creates/deletes of Compute and Network resources are long running; permissions allow the ability to query status periodically



"Microsoft.Compute/virtualMachines/read",
"Microsoft.Compute/virtualMachines/write",
"Microsoft.Compute/virtualMachines/delete",
//Required to allow create, update and delete VM's



"Microsoft.Compute/virtualMachineScaleSets/read",
"Microsoft.Compute/virtualMachineScaleSets/write",
"Microsoft.Compute/virtualMachineScaleSets/delete",
//Required to allow create, update and delete VMSS's



"Microsoft.Network/loadBalancers/read",
"Microsoft.Network/loadBalancers/write",
"Microsoft.Network/loadBalancers/delete",
// Not needed today, however will need when we have SLB


 
"Microsoft.Network/networkInterfaces/read",
"Microsoft.Network/networkInterfaces/write",
"Microsoft.Network/networkInterfaces/delete",
//Required to allow create, update and delete NIC's 



"Microsoft.Network/networkSecurityGroups/read",
"Microsoft.Network/networkSecurityGroups/write",
"Microsoft.Network/networkSecurityGroups/delete",
// if cloud provider can provision/remove NSG, then we can remove these permissions and the default NSG we create



"Microsoft.Network/publicIPAddresses/read",
"Microsoft.Network/publicIPAddresses/write",
"Microsoft.Network/publicIPAddresses/delete",
// We should remove this as we DO NOT create public ips by default .. possibly need it for SLB 





"Microsoft.Network/virtualNetworks/read",
"Microsoft.Network/virtualNetworks/write",
"Microsoft.Network/virtualNetworks/delete",
//Required to allow create, update and delete VNETs 

 
"Microsoft.Network/routeTables/read",
"Microsoft.Network/routeTables/write",
"Microsoft.Network/routeTables/delete",
//Required to allow create, update and delete route tables 



"Microsoft.Resources/deployments/read",
"Microsoft.Resources/deployments/write",
"Microsoft.Resources/deployments/delete",
// required to allow ARM template deployments


"Microsoft.Resources/subscriptions/resourceGroups/read",
"Microsoft.Resources/subscriptions/resourceGroups/write",
"Microsoft.Resources/subscriptions/resourceGroups/delete",
//Required to allow create, update and delete RG's 



"Microsoft.Storage/checkNameAvailability/read",
"Microsoft.Storage/checkNameAvailability/write",
"Microsoft.Storage/checkNameAvailability/delete",
// Dont have storage accounts anymore.. Need to remove



"Microsoft.Storage/operations/read",
"Microsoft.Storage/storageAccounts/read",
"Microsoft.Storage/storageAccounts/write",
"Microsoft.Storage/storageAccounts/listKeys/action",
// Dont have storage accounts anymore.. Need to remove

 
// required if you use custom vnet
"Microsoft.Network/virtualNetworks/subnets/write"
//Required to allow update subnets's 


For custom VNET + CNI 
https://docs.microsoft.com/en-us/azure/aks/configure-azure-cni#prerequisites

points out only join and read are required


For Kubenet + CNI, this permission is actually required to update the subnet
in this step
https://docs.microsoft.com/en-us/azure/aks/configure-kubenet#associate-network-resources-with-the-node-subnet

 
// required if you use container insights.
"Microsoft.OperationalInsights/workspaces/sharedkeys/read"
"Microsoft.OperationalInsights/workspaces/read"
"Microsoft.OperationsManagement/solutions/write"
"Microsoft.OperationsManagement/solutions/read"
//Required to allow create, update Log Analytics workspaces and Azure monitoring for Containers 


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

{"kind":"Event","apiVersion":"audit.k8s.io/v1","level":"Request","auditID":"130ba120-d9b1-4b35-9e91-3366568bfd8d","stage":"ResponseComplete","requestURI":"/api/v1/namespaces/default/pods/nginx","verb":"get","user":{"username":"masterclient","groups":["system:masters","system:authenticated"]},"sourceIPs":["52.191.253.156"],"userAgent":"kubectl/v1.14.0 (linux/amd64) kubernetes/641856d","objectRef":{"resource":"pods","namespace":"default","name":"nginx","apiVersion":"v1"},"responseStatus":{"metadata":{},"status":"Failure","reason":"NotFound","code":404},"requestReceivedTimestamp":"2019-09-20T11:52:19.062985Z","stageTimestamp":"2019-09-20T11:52:19.068391Z","annotations":{"authorization.k8s.io/decision":"allow","authorization.k8s.io/reason":""}}

 

{"kind":"Event","apiVersion":"audit.k8s.io/v1","level":"Request","auditID":"e13ca54f-9b7a-4a47-abb4-930d0b518c49","stage":"ResponseComplete","requestURI":"/api/v1/namespaces/default/pods/nginx/status","verb":"patch","user":{"username":"nodeclient","groups":["system:nodes","system:authenticated"]},"sourceIPs":["13.88.18.92"],"userAgent":"kubelet/v1.14.5 (linux/amd64) kubernetes/0e9fcb4","objectRef":{"resource":"pods","namespace":"default","name":"nginx","apiVersion":"v1","subresource":"status"},"responseStatus":{"metadata":{},"code":200},"requestObject":{"status":{"$setElementOrder/conditions":[{"type":"Initialized"},{"type":"Ready"},{"type":"ContainersReady"},{"type":"PodScheduled"}],"conditions":[{"lastTransitionTime":"2019-09-20T12:56:55Z","message":null,"reason":null,"status":"True","type":"Ready"},{"lastTransitionTime":"2019-09-20T12:56:55Z","message":null,"reason":null,"status":"True","type":"ContainersReady"}],"containerStatuses":[{"containerID":"docker://e4d6babb34b671237490bbf384326c142281bcabe0c74416ea63088146ed1500","image":"nginx:1.15.5","imageID":"docker-pullable://nginx@sha256:b73f527d86e3461fd652f62cf47e7b375196063bbbd503e853af5be16597cb2e","lastState":{},"name":"mypod","ready":true,"restartCount":0,"state":{"running":{"startedAt":"2019-09-20T12:56:55Z"}}}],"phase":"Running","podIP":"10.244.4.11"}},"requestReceivedTimestamp":"2019-09-20T12:56:55.895345Z","stageTimestamp":"2019-09-20T12:56:55.910588Z","annotations":{"authorization.k8s.io/decision":"allow","authorization.k8s.io/reason":"RBAC: allowed by ClusterRoleBinding \"system:aks-client-nodes\" of ClusterRole \"system:node\" to Group \"system:nodes\""}}

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