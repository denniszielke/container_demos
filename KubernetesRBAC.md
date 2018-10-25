# Kubernetes Role based acccess control

0. Variables
```
KUBE_GROUP=kuberbac
KUBE_NAME=dzkuberbac
LOCATION="eastus"
SUBSCRIPTION_ID=
AAD_APP_ID=
AAD_APP_SECRET=
AAD_CLIENT_ID=
TENANT_ID=
YOUR_SSH_KEY=$(cat ~/.ssh/id_rsa.pub)
SERVICE_PRINCIPAL_ID=
SERVICE_PRINCIPAL_SECRET=
ADMIN_GROUP_ID=
MY_OBJECT_ID=
KUBE_ADMIN_ID=
READER_USER_ID=
```

## Create RBAC with AKs
```
az group create --name $KUBE_GROUP --location $LOCATION

az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --ssh-key-value ~/.ssh/id_rsa.pub --enable-rbac --aad-server-app-id $AAD_APP_ID --aad-server-app-secret $AAD_APP_SECRET --aad-client-app-id $AAD_CLIENT_ID --aad-tenant-id $TENANT_ID --client-secret $SERVICE_PRINCIPAL_SECRET --service-principal $SERVICE_PRINCIPAL_ID --enable-addons http_application_routing

az aks get-credentials --resource-group $KUBE_GROUP --name $KUBE_NAME --admin
```

set cluster role binding
```
cat <<EOF | kubectl create -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: kube-cluster-admins
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: User
  name: "user@microsoft.com"
EOF
```

create admin user binding
```
cat <<EOF | kubectl create -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cluster-kube-admins
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: User
  name: "$MY_OBJECT_ID"
- apiGroup: rbac.authorization.k8s.io
  kind: User
  name: "$MY_USER_ID"
EOF

az aks get-credentials --resource-group $KUBE_GROUP --name $KUBE_NAME

az aks browse --resource-group $KUBE_GROUP --name $KUBE_NAME
```

if you see the following error message
error: unable to forward port because pod is not running. Current status=Pending
create a binding for the dashboard account
```
kubectl create clusterrolebinding kubernetes-dashboard --clusterrole=cluster-admin --serviceaccount=kube-system:kubernetes-dashboard
```

or yaml

```
cat <<EOF | kubectl create -f -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: kubernetes-dashboard
  labels:
    k8s-app: kubernetes-dashboard
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: kubernetes-dashboard
  namespace: kube-system
EOF

cat <<EOF | kubectl create -f -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: kubernetes-default
  labels:
    k8s-app: kubernetes-default
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: default
  namespace: kube-system
EOF
```

## Create namespaces and trimmed roles

```
kubectl create ns small
kubectl create ns big

cat <<EOF | kubectl create -f -
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  namespace: small
  name: pod-and-pod-logs-reader
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log"]
  verbs: ["get", "list"]
EOF

cat <<EOF | kubectl create -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  namespace: small
  name: small-pod-reader
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: pod-and-pod-logs-reader
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: User
  name: "$READER_USER_ID"
EOF

kubectl create rolebinding small-pod-reader --role=pod-and-pod-logs-reader --user=$READER_USER_ID --namespace=small

kubectl auth can-i create deployments --namespace=small --as=$READER_USER_ID

kubectl auth can-i list pods --namespace=small --as=$READER_USER_ID
```

## Prepare acs-engine

```
sed -e "s/AAD_APP_ID/$AAD_APP_ID/ ; s/AAD_CLIENT_ID/$AAD_CLIENT_ID/ ; s/SERVICE_PRINCIPAL_ID/$SERVICE_PRINCIPAL_ID/ ; s/SERVICE_PRINCIPAL_SECRET/$SERVICE_PRINCIPAL_SECRET/ ; s/TENANT_ID/$TENANT_ID/" acsengrbac.json > acsengkubernetes.json
docker pull ams0/acs-engine-light-autobuild
mkdir deployment
docker run -it --rm -v deployment:/acs -w /acs ams0/acs-engine-light-autobuild:latest /acs-engine generate acsengkubernetes.json
```

## Deploy cluster

```
az login

az group create -n $KUBE_GROUP -l $LOCATION

az group deployment create \
    --name dz-aad-k8s-18 \
    --resource-group $KUBE_GROUP \
    --template-file "_output/dz-aad-k8s-18/azuredeploy.json" \
    --parameters "_output/dz-aad-k8s-18/azuredeploy.parameters.json"
```

## Create cluster role binding

```
export KUBECONFIG=`pwd`/_output/dz-aad-k8s-18/kubeconfig/kubeconfig.northeurope.json

ssh -i ~/.ssh/id_rsa dennis@dz-aad-k8s-18.northeurope.cloudapp.azure.com \
    kubectl create clusterrolebinding aad-default-cluster-admin-binding \
        --clusterrole=cluster-admin \
        --user 'https://sts.windows.net/<tenant-id>/#<user-id>'

kubectl create clusterrolebinding aad-default-cluster-admin-binding --clusterrole=cluster-admin --user=https://sts.windows.net/$TENANT_ID/#$MY_OBJECT_ID
```

## Verify with can-i
```
kubectl auth can-i create deployments 
```
