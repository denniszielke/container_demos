# ACS

```
KUBE_NAME="dzstrg9"
KUBE_GROUP="$KUBE_NAME"

az aks nodepool list -g $KUBE_GROUP --cluster-name $KUBE_NAME -o table  
az aks nodepool update --resource-group $KUBE_GROUP --cluster-name $KUBE_NAME --name nodepool1 --labels acstor.azure.com/io-engine=acstor


AKS_MI_OBJECT_ID=$(az aks show --name $KUBE_NAME --resource-group $KUBE_GROUP --query "identityProfile.kubeletidentity.objectId" -o tsv)
AKS_NODE_RG=$(az aks show --name $KUBE_NAME --resource-group $KUBE_GROUP --query "nodeResourceGroup" -o tsv)
az role assignment create --assignee $AKS_MI_OBJECT_ID --role "Contributor" --resource-group "$AKS_NODE_RG"
az role assignment create --assignee $AKS_MI_OBJECT_ID --role "Reader" --resource-group "$KUBE_GROUP"

az k8s-extension create --cluster-type managedClusters --cluster-name $KUBE_NAME --resource-group $KUBE_GROUP --name acs --extension-type microsoft.azurecontainerstorage --scope cluster --release-train prod --release-namespace acstor

cat <<EOF | kubectl apply -f -
apiVersion: containerstorage.azure.com/v1alpha1
kind: StoragePool
metadata:
  name: azuredisk
  namespace: acstor
spec:
  poolType:
    azureDisk: {}
  resources:
    requests: {"storage": 10Gi}
EOF

kubectl describe sp azuredisk -n acstor

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: azurediskpvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: acstor-azuredisk # replace with the name of your storage class if different
  resources:
    requests:
      storage: 1Gi
EOF

cat <<EOF | kubectl apply -f -
kind: Pod
apiVersion: v1
metadata:
  name: fiopod
spec:
  nodeSelector:
    acstor.azure.com/io-engine: acstor
  volumes:
    - name: azurediskpv
      persistentVolumeClaim:
        claimName: azurediskpvc
  containers:
    - name: fio
      image: nixery.dev/shell/fio
      args:
        - sleep
        - "1000000"
      volumeMounts:
        - mountPath: "/volume"
          name: azurediskpv
EOF

kubectl exec -it fiopod -- fio --name=benchtest --size=800m --filename=/volume/test --direct=1 --rw=randrw --ioengine=libaio --bs=4k --iodepth=16 --numjobs=8 --time_based --runtime=60


```