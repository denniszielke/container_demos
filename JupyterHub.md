# Installing JupyterHub on azure files

## Create azure files default storage class
https://kubernetes.io/docs/tasks/administer-cluster/change-default-storage-class/


### Create storage account
```
KUBE_GROUP=kub_ter_k_m_jupnorbac5
KUBE_NAME=jupnorbac5
LOCATION=westeurope
STORAGE_ACCOUNT=dzjupyteruserstore

az storage account create --resource-group  MC_$(echo $KUBE_GROUP)_$(echo $KUBE_NAME)_$(echo $LOCATION) --name $STORAGE_ACCOUNT --location $LOCATION --sku Standard_LRS --kind StorageV2 --access-tier hot --https-only false
```

### Patch storage default class and create cluster-admin role
```
cat <<EOF | kubectl apply -f -
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: azurefile
provisioner: kubernetes.io/azure-file
parameters:
  skuName: Standard_LRS
  location: $LOCATION
  storageAccount: $STORAGE_ACCOUNT
EOF


cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  creationTimestamp: null
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: cluster-admin
rules:
- apiGroups:
  - '*'
  resources:
  - '*'
  verbs:
  - '*'
- nonResourceURLs:
  - '*'
  verbs:
  - '*'
EOF

```
## Install JupyterHub
https://zero-to-jupyterhub.readthedocs.io/en/stable/setup-jupyterhub.html

```
openssl rand -hex 32
```

create config.yaml with content
```
proxy:
  secretToken: "774629f880afc0302830c19a9f09be4f59e98b242b65983cea7560e828df2978"
singleuser:
  storage:
    dynamic:
      storageClass: azurefile
rbac:
   enabled: false
```

install jhub
```
helm repo add jupyterhub https://jupyterhub.github.io/helm-chart/
helm repo update

RELEASE=jhub
NAMESPACE=jhub

helm upgrade --install $RELEASE jupyterhub/jupyterhub \
  --namespace $NAMESPACE  \
  --version 0.7.0 \
  --values config.yaml


helm delete jhub --purge
kubectl delete ns jhub
```
