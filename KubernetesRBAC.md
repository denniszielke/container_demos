# Kubernetes Role based acccess control
## Create container cluster (currently only with acs-engine)

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
MY_USER_ID=
```

## Create RBAC with AKs
```
az group create --name $KUBE_GROUP --location $LOCATION

az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --ssh-key-value ~/.ssh/id_rsa.pub --enable-rbac --aad-server-app-id $AAD_APP_ID --aad-server-app-secret $AAD_APP_SECRET --aad-client-app-id $AAD_CLIENT_ID --aad-tenant-id $TENANT_ID --client-secret $SERVICE_PRINCIPAL_SECRET --service-principal $SERVICE_PRINCIPAL_ID

az aks get-credentials --resource-group $KUBE_GROUP --name $KUBE_NAME --admin

```
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: contoso-cluster-admins
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: User
  name: "user@contoso.com"
```

```
cat <<EOF | kubectl create -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: contoso-cluster-admins
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: User
  name: "$MY_USER_ID"
EOF

az aks get-credentials --resource-group $KUBE_GROUP --name $KUBE_NAME


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