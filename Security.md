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
```

after 1.8
```
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
```

create bearer token
```
kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep edit-user | awk '{print $1}')

kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep my-dashboard-sa | awk '{print $1}')
```

Set kubectl context
```
kubectl config set-cluster low-cluster --server=$KUBE_MANAGEMENT_ENDPOINT --insecure-skip-tls-verify=true

kubectl config set-credentials edit-user --token=$TOKEN

kubectl config set-context low-context --cluster=low-cluster --user=edit-user

kubectl config use-context low-context
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

kubectl run -it aks-ssh --image=debian

apt-get update && apt-get install openssh-client -y

aks-ssh-6fd7758688-9crp5 

kubectl cp ~/.ssh/id_rsa aks-ssh-6fd7758688-9crp5:/id_rsa

chmod 0600 id_rsa

ssh -i id_rsa dennis@10.0.5.4

sudo add-apt-repository ppa:wireshark-dev/stable
sudo apt-get update
sudo apt-get install wireshark
sudo apt install tshark
sudo dpkg-reconfigure wireshark-common
sudo usermod -a -G wireshark dennis

tshark -Q -i2 -O http -T json tcp port 7001 | grep http.file_data

