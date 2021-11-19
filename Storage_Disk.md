# Disk

```
NODE_GROUP=$(az aks show --resource-group $KUBE_GROUP --name $KUBE_NAME --query nodeResourceGroup -o tsv)
DISK_ID=$(az disk create --resource-group $NODE_GROUP --name myAKSDisk --size-gb 20 --query id --output tsv)

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: stapps
spec:
  replicas: 1
  selector:
    matchLabels:
      name: stapps  
  template:
    metadata:
      labels:
        name: stapps        
    spec:
      containers:
      - name: stapps
        image: mcr.microsoft.com/oss/nginx/nginx:1.15.5-alpine
        volumeMounts:
          - name: azure
            mountPath: /mnt/azure
      volumes:
        - name: azure
          azureDisk:
            kind: Managed
            diskName: myAKSDisk
            diskURI: $DISK_ID
EOF
```

## Install CSI Driver
https://github.com/kubernetes-sigs/azuredisk-csi-driver

curl -skSL https://raw.githubusercontent.com/kubernetes-sigs/azuredisk-csi-driver/master/deploy/install-driver.sh | bash -s master --

Uninstall
curl -skSL https://raw.githubusercontent.com/kubernetes-sigs/azuredisk-csi-driver/master/deploy/uninstall-driver.sh | bash -s master --


## CSI Migration

Hostpath
```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: task-pv-volume
  labels:
    type: local
spec:
  storageClassName: manual
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/var/log"
EOF

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: task-pv-claim
spec:
  storageClassName: manual
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 3Gi
EOF
```


## Zone
https://github.com/kubernetes-sigs/azuredisk-csi-driver/blob/master/deploy/example/e2e_usage.md

```
curl -skSL https://raw.githubusercontent.com/kubernetes-sigs/azuredisk-csi-driver/master/deploy/install-driver.sh | bash -s master --

kubectl describe nodes | grep -e "Name:" -e "failure-domain.beta.kubernetes.io/zone"
kubectl get no --show-labels | grep topo

cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: managed-zone-csi
provisioner: disk.csi.azure.com
parameters:
  skuname: Premium_ZRS
reclaimPolicy: Delete
volumeBindingMode: Immediate
EOF

cat <<EOF | kubectl apply -f -
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: pvc-zone-azuredisk
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: "managed-zone-csi"
EOF


cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: stapps
spec:
  replicas: 1
  selector:
    matchLabels:
      name: stapps  
  template:
    metadata:
      labels:
        name: stapps        
    spec:
      containers:
        - image: mcr.microsoft.com/oss/nginx/nginx:1.17.3-alpine
          name: nginx-azuredisk
          command:
            - "/bin/sh"
            - "-c"
            - while true; do echo $(date) >> /mnt/azuredisk/outfile; sleep 1; done
          volumeMounts:
          - name: azuredisk01
            mountPath: "/mnt/azuredisk"
      volumes:
        - name: azuredisk01
          persistentVolumeClaim:
            claimName: pvc-zone-azuredisk
EOF


---
kind: Pod
apiVersion: v1
metadata:
  name: nginx-azuredisk
spec:
  nodeSelector:
    kubernetes.io/os: linux
  containers:
    - image: mcr.microsoft.com/oss/nginx/nginx:1.17.3-alpine
      name: nginx-azuredisk
      command:
        - "/bin/sh"
        - "-c"
        - while true; do echo $(date) >> /mnt/azuredisk/outfile; sleep 1; done
      volumeMounts:
        - name: azuredisk01
          mountPath: "/mnt/azuredisk"
  volumes:
    - name: azuredisk01
      persistentVolumeClaim:
        claimName: pvc-azuredisk

az disk

```