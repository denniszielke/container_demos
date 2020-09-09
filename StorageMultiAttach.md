# Multi Attach Storage
https://github.com/kubernetes-sigs/azuredisk-csi-driver/tree/master/deploy/example/sharedisk

https://github.com/kubernetes-sigs/azuredisk-csi-driver/blob/master/docs/install-csi-driver-master.md
https://docs.microsoft.com/en-gb/azure/virtual-machines/linux/disks-shared
https://discourse.ubuntu.com/t/ubuntu-high-availability-corosync-pacemaker-shared-disk-environments/14874
https://datamattsson.tumblr.com/post/187582900281/running-traditional-ha-clusters-on-kubernetes

KUBE_GROUP="dzielkedefstor"
KUBE_NAME="aksdiskshared"
LOCATION="westcentralus"
KUBE_VERSION="1.18.6"
ENG_SUB_ID

az account set --subscription $ENG_SUB_ID

az feature register --namespace "Microsoft.Compute" --name "SharedDisksForPremium"
az feature register --name UseCustomizedContainerRuntime --namespace Microsoft.ContainerService
az feature register --name UseCustomizedUbuntuPreview --namespace Microsoft.ContainerService

az provider register --namespace Microsoft.ContainerService

SERVICE_PRINCIPAL_ID=$(az ad sp create-for-rbac --skip-assignment --name $KUBE_NAME-sp -o json | jq -r '.appId')
echo $SERVICE_PRINCIPAL_ID

SERVICE_PRINCIPAL_SECRET=$(az ad app credential reset --id $SERVICE_PRINCIPAL_ID -o json | jq '.password' -r)
echo $SERVICE_PRINCIPAL_SECRET

az group create -n $KUBE_GROUP -l $LOCATION

az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --vm-set-type VirtualMachineScaleSets --load-balancer-sku standard --kubernetes-version $KUBE_VERSION \
    --node-count 3 --client-secret $SERVICE_PRINCIPAL_SECRET --service-principal $SERVICE_PRINCIPAL_ID --aks-custom-headers CustomizedUbuntu=aks-ubuntu-1804,ContainerRuntime=containerd

Check if the feature is active
```
az feature list -o table --query "[?contains(name, 'Microsoft.RedHatOpenShift')].{Name:name,State:properties.state}"

curl -skSL https://raw.githubusercontent.com/kubernetes-sigs/azuredisk-csi-driver/master/deploy/install-driver.sh | bash -s master --


cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: managed-csi
provisioner: disk.csi.azure.com
parameters:
  skuname: Premium_LRS  # Currently shared disk only available with premium SSD
  maxShares: "2"
  cachingMode: None  # ReadOnly cache is not available for premium SSD with maxShares>1
reclaimPolicy: Delete
---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: pvc-azuredisk
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 256Gi  # minimum size of shared disk is 256GB (P15)
  volumeMode: Block
  storageClassName: managed-csi
EOF

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: nginx
  name: deployment-azuredisk
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
      name: deployment-azuredisk
    spec:
      ports:
      containers:
        - name: deployment-azuredisk
          image: nginx
          ports:
          - containerPort: 80
          volumeDevices:
            - name: azuredisk
              devicePath: /dev/sdx
      volumes:
        - name: azuredisk
          persistentVolumeClaim:
            claimName: pvc-azuredisk
EOF

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: ubuntu
  name: deployment-ubuntu
spec:
  replicas: 2
  selector:
    matchLabels:
      app: ubuntu
  template:
    metadata:
      labels:
        app: ubuntu
      name: deployment-ubuntu
    spec:
      ports:
      containers:
        - name: deployment-ubuntu
          image: ubuntu
          ports:
          - containerPort: 80
          command:
          - sleep
          - "3600"
          volumeDevices:
            - name: azuredisk
              devicePath: /dev/sdx
      volumes:
        - name: azuredisk
          persistentVolumeClaim:
            claimName: pvc-azuredisk
EOF

POD1=deployment-ubuntu-64f568d66b-ln59r
POD2=deployment-ubuntu-64f568d66b-wq4cv

dd if=/dev/zero of=/dev/sdx bs=1024k count=1024

du -sh /dev/sdx

losetup -fP /dev/sdx

kubectl exec -it $POD1 -- /bin/bash
kubectl exec -it $POD2 -- /bin/bash

mkfs.ext4 /dev/sdx

losetup /dev/loop0 /dev/sdx


cat /proc/mounts | grep /dev/loop

mkdir /mnt/shareddrive

mount -o loop=/dev/loop0 /dev/sdx /mnt/shareddrive


echo 'Hello shell demo' > /dev/sdx/a.txt



blkid

mkdir /mnt/shareddrive
ls /mnt/

mount -t ext4 -U 924ad3a0-0515-4f5e-babe-3824e5c3d33e  /mnt/shareddrive

sudo mount -o ro,noload /dev/sdx /mnt/shareddrive

mount -o ro -t ext4 /dev/sdx  /mnt/shareddrive

df -h

https://opensource.com/article/19/4/create-filesystem-linux-partition


cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: azure-managed-disk
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: managed-premium
  resources:
    requests:
      storage: 5Gi
EOF

cat <<EOF | kubectl apply -f -
kind: Pod
apiVersion: v1
metadata:
  name: mypod
spec:
  containers:
  - name: mypod
    image: nginx:1.15.5
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 250m
        memory: 256Mi
    volumeMounts:
    - mountPath: "/mnt/azure"
      name: volume
  volumes:
    - name: volume
      persistentVolumeClaim:
        claimName: azure-managed-disk
EOF