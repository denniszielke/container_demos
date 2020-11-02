# Installing JupyterHub in AKS

## create postgres db

create postgres db
```
KUBE_GROUP=kub_ter_k_l_juphub
KUBE_NAME=juphub
LOCATION=westeurope
STORAGE_ACCOUNT=dzjupyteruser
PSQL_PASSWORD=$(openssl rand -base64 10)

az postgres server create --resource-group $KUBE_GROUP --name $KUBE_NAME  --location $LOCATION --admin-user myadmin --admin-password $PSQL_PASSWORD --sku-name GP_Gen4_2 --version 9.6
```

lock up details
```
az postgres server show --resource-group $KUBE_GROUP --name $KUBE_NAME
```

connect to psql using shell.azure.com and create database for jupyterhub
```
psql --host=$KUBE_NAME.postgres.database.azure.com --username=myadmin@$KUBE_NAME --dbname=postgres --port=5432

CREATE DATABASE jupyterhub;
```

## create storage account

```
az storage account create --resource-group  MC_$(echo $KUBE_GROUP)_$(echo $KUBE_NAME)_$(echo $LOCATION) --name $STORAGE_ACCOUNT --location $LOCATION --sku Standard_LRS --kind StorageV2 --access-tier hot --https-only false
```

create azure file storage class
```
cat <<EOF | kubectl apply -f -
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
  location: $LOCATION
  storageAccount: $STORAGE_ACCOUNT
EOF
```

## deploy jupyterhub without RBAC

```
openssl rand -hex 32
```

create config.yaml with content
```
cat  <<EOF >config.yaml
proxy:
  secretToken: "774629f880afc0302830c19a9f09be4f59e98b242b65983cea7560e828df2978"
hub:
  uid: 1000
  cookieSecret: "774629f880afc0302830c19a9f09be4f59e98b242b65983cea7560e828df2978"
  db:
    type: postgres
    url: postgres+psycopg2://myadmin@$KUBE_NAME:$PSQL_PASSWORD@$KUBE_NAME.postgres.database.azure.com:5432/jupyterhub
singleuser:
  storage:
    dynamic:
      storageClass: azurefile
rbac:
   enabled: false
EOF

cat  <<EOF >config.yaml
proxy:
  secretToken: "774629f880afc0302830c19a9f09be4f59e98b242b65983cea7560e828df2978"
hub:
  uid: 1000
  cookieSecret: "774629f880afc0302830c19a9f09be4f59e98b242b65983cea7560e828df2978"
rbac:
   enabled: true
EOF
```

install jhub
```
helm repo add jupyterhub https://jupyterhub.github.io/helm-chart/
helm repo update

RELEASE=jhub1
NAMESPACE=jhub1

helm upgrade --cleanup-on-fail \
  --install $RELEASE jupyterhub/jupyterhub \
  --namespace $NAMESPACE \
  --create-namespace \
  --version=0.9.0 \
  --values config.yaml

kubectl get service --namespace jhub

```

cleanup

```
helm delete jhub --purge
kubectl delete ns jhub
```

## deploy jupyterhub in cluster with rbac

create cloud provider azure files role

```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: azurefilestore
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: azurefile
  resources:
    requests:
      storage: 5Gi
EOF
```

```
cat <<EOF | kubectl apply -f -
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
EOF
```

```
openssl rand -hex 32
```

create config.yaml with content
```
cat  <<EOF >config.yaml
proxy:
  secretToken: "774629f880afc0302830c19a9f09be4f59e98b242b65983cea7560e828df2978"
hub:
  uid: 1000
  cookieSecret: "774629f880afc0302830c19a9f09be4f59e98b242b65983cea7560e828df2978"
  db:
    type: postgres
    url: postgres+psycopg2://myadmin@$KUBE_NAME:$PSQL_PASSWORD@$KUBE_NAME.postgres.database.azure.com:5432/jupyterhub
singleuser:
  storage:
    dynamic:
      storageClass: azurefile
rbac:
   enabled: true
EOF

cat  <<EOF >config.yaml
proxy:
  secretToken: "774629f880afc0302830c19a9f09be4f59e98b242b65983cea7560e828df2978"
hub:
  uid: 1000
  cookieSecret: "774629f880afc0302830c19a9f09be4f59e98b242b65983cea7560e828df2978"
rbac:
   enabled: true
EOF
```

install jhub
```

RELEASE=jhub
NAMESPACE=jhub

helm upgrade --install $RELEASE jupyterhub/jupyterhub \
  --namespace $NAMESPACE  \
  --version 0.7.0 \
  --values config.yaml
```

cleanup

```
helm delete jhub --purge
kubectl delete ns jhub
```
