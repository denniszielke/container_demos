# Installing JupyterHub on azure files

## Create azure files default storage class
https://kubernetes.io/docs/tasks/administer-cluster/change-default-storage-class/
https://zero-to-jupyterhub.readthedocs.io/en/stable/setup-jupyterhub.html

```
KUBE_GROUP=juprbac5
KUBE_NAME=juprbac5
LOCATION=westeurope
STORAGE_ACCOUNT=dzjupyteruserrbac

az storage account create --resource-group  MC_$(echo $KUBE_GROUP)_$(echo $KUBE_NAME)_$(echo $LOCATION) --name $STORAGE_ACCOUNT --location $LOCATION --sku Standard_LRS --kind StorageV2 --access-tier hot --https-only false
```

## cluster without rbac

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
```


### deploy jupyterhub
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
```

cleanup

```
helm delete jhub --purge
kubectl delete ns jhub
```

## cluster with rbac
https://zero-to-jupyterhub.readthedocs.io/en/stable/reference.html#helm-chart-configuration-reference
https://github.com/jupyterhub/zero-to-jupyterhub-k8s/blob/master/jupyterhub/templates/hub/pvc.yaml

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
```

### create cloud provider azure files role

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

### deploy jupyterhub
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