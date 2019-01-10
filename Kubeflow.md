
```
KNAMESPACE=myflow
kubectl create namespace $KNAMESPACE
ks init $KNAMESPACE && cd $KNAMESPACE
ks env set default --namespace $KNAMESPACE
ks registry add kubeflow github.com/kubeflow/kubeflow/tree/master/kubeflow
ks pkg install kubeflow/core
ks pkg install kubeflow/tf-serving
ks pkg install kubeflow/tf-job
ks generate core kubeflow-core --name=kubeflow-core --namespace=$KNAMESPACE
ks param set kubeflow-core cloud acsengine
ks apply default -c kubeflow-core
kubectl get services --namespace=$KNAMESPACE
```

az storage account create --resource-group akskube --name dzkubeflowfiles --location westeurope --sku Standard_LRS

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
  storageAccount: mystorageaccount