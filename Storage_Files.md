# CSI Drivers


```
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
KUBE_GROUP="kub_ter_a_m_csisecurity"
KUBE_NAME="csisecurity"
LOCATION="eastus"
NODE_GROUP=$KUBE_GROUP"_"$KUBE_NAME"_nodes_"$LOCATION
KUBE_VNET_NAME=$KUBE_NAME"-vnet"
KUBE_GW_SUBNET_NAME="gw-1-subnet"
KUBE_ACI_SUBNET_NAME="aci-2-subnet"
KUBE_FW_SUBNET_NAME="AzureFirewallSubnet"
KUBE_ING_SUBNET_NAME="ing-4-subnet"
KUBE_AGENT_SUBNET_NAME="aks-5-subnet"
KUBE_AGENT2_SUBNET_NAME="aks-6-subnet"
KUBE_VERSION="$(az aks get-versions -l $LOCATION --query 'orchestrators[?default == `true`].orchestratorVersion' -o tsv)"
```


```
az group create -n $KUBE_GROUP -l $LOCATION
az network vnet create -g $KUBE_GROUP -n $KUBE_VNET_NAME 

az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_GW_SUBNET_NAME --address-prefix 10.0.1.0/24
az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_ACI_SUBNET_NAME --address-prefix 10.0.2.0/24 --service-endpoints Microsoft.Sql Microsoft.AzureCosmosDB Microsoft.KeyVault
az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_FW_SUBNET_NAME --address-prefix 10.0.3.0/24
az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_ING_SUBNET_NAME --address-prefix 10.0.4.0/24
az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_AGENT_SUBNET_NAME --address-prefix 10.0.5.0/24 --service-endpoints Microsoft.Sql Microsoft.AzureCosmosDB Microsoft.KeyVault Microsoft.Storage
az network vnet subnet create -g $KUBE_GROUP --vnet-name $KUBE_VNET_NAME -n $KUBE_AGENT2_SUBNET_NAME --address-prefix 10.0.6.0/24 --service-endpoints Microsoft.Sql Microsoft.AzureCosmosDB Microsoft.KeyVault Microsoft.Storage

echo "creating cluster 1 with MSI"

KUBE_AGENT_SUBNET_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$KUBE_GROUP/providers/Microsoft.Network/virtualNetworks/$KUBE_VNET_NAME/subnets/$KUBE_AGENT_SUBNET_NAME"
KUBE_VNET_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$KUBE_GROUP/providers/Microsoft.Network/virtualNetworks/$KUBE_VNET_NAME"

az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --node-count 3 --ssh-key-value ~/.ssh/id_rsa.pub  --enable-vmss --network-plugin azure --vnet-subnet-id $KUBE_AGENT_SUBNET_ID --docker-bridge-address 172.17.0.1/16 --dns-service-ip 10.2.0.10 --service-cidr 10.2.0.0/24 --kubernetes-version $KUBE_VERSION --node-resource-group $NODE_GROUP --enable-managed-identity --network-policy calico --enable-rbac --enable-addons monitoring --aks-custom-headers EnableAzureDiskFileCSIDriver=true --node-vm-size Standard_D4as_v4

KUBELET_ID=$(az aks show -g $KUBE_GROUP -n $KUBE_NAME --query identityProfile.kubeletidentity.clientId -o tsv)
CONTROLLER_ID=$(az aks show -g $KUBE_GROUP -n $KUBE_NAME --query identity.principalId -o tsv)
NODE_GROUP=$(az aks show --resource-group $KUBE_GROUP --name $KUBE_NAME --query nodeResourceGroup -o tsv)

az role assignment create --role "Virtual Machine Contributor" --assignee $KUBELET_ID --scope /subscriptions/$SUBSCRIPTION_ID/resourcegroups/$NODE_GROUP
az role assignment create --role "Virtual Machine Contributor" --assignee $CONTROLLER_ID --scope $KUBE_VNET_ID

az role assignment create --role "Contributor" --assignee $CONTROLLER_ID -g $KUBE_GROUP
az role assignment create --role "Contributor" --assignee $CONTROLLER_ID -g $NODE_GROUP

echo "creating cluster 2 with SP"

SP_NAME="$KUBE_NAME-sp"
SERVICE_PRINCIPAL_ID=$(az ad sp create-for-rbac --skip-assignment --name $SP_NAME -o json | jq -r '.appId')
echo $SERVICE_PRINCIPAL_ID

SERVICE_PRINCIPAL_SECRET=$(az ad app credential reset --id $SERVICE_PRINCIPAL_ID -o json | jq '.password' -r)
echo $SERVICE_PRINCIPAL_SECRET

KUBE_AGENT_SUBNET2_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$KUBE_GROUP/providers/Microsoft.Network/virtualNetworks/$KUBE_VNET_NAME/subnets/$KUBE_AGENT2_SUBNET_NAME"
KUBE_VNET_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$KUBE_GROUP/providers/Microsoft.Network/virtualNetworks/$KUBE_VNET_NAME"
NODE2_GROUP=$KUBE_GROUP"_"$KUBE_NAME"2_nodes_"$LOCATION

az role assignment create --role "Contributor" --assignee $SERVICE_PRINCIPAL_ID -g $KUBE_GROUP

az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME-sp --node-count 3 --ssh-key-value ~/.ssh/id_rsa.pub  --enable-vmss --network-plugin azure --vnet-subnet-id $KUBE_AGENT_SUBNET2_ID --docker-bridge-address 172.17.0.1/16 --dns-service-ip 10.2.0.10 --service-cidr 10.2.0.0/24 --kubernetes-version $KUBE_VERSION --node-resource-group $NODE2_GROUP --client-secret $SERVICE_PRINCIPAL_SECRET --service-principal $SERVICE_PRINCIPAL_ID --network-policy calico --enable-rbac --enable-addons monitoring --aks-custom-headers EnableAzureDiskFileCSIDriver=true --node-vm-size Standard_D4as_v4

```

## Azure Disk

https://github.com/kubernetes-sigs/azuredisk-csi-driver


### Cloning
https://github.com/kubernetes-sigs/azuredisk-csi-driver/tree/master/deploy/example/cloning

https://raw.githubusercontent.com/kubernetes-sigs/azuredisk-csi-driver/master/deploy/example/cloning/pvc-azuredisk-cloning.yaml


### CSI Topology Features
https://kubernetes-csi.github.io/docs/topology.html

# Storage Account
```
STORAGE_ACCOUNT=$KUBE_NAME

NODE_GROUP=$(az aks show --resource-group $KUBE_GROUP --name $KUBE_NAME --query nodeResourceGroup -o tsv)

az storage account create --resource-group $NODE_GROUP --name $STORAGE_ACCOUNT --location $LOCATION --sku Premium_LRS --kind FileStorage --access-tier hot --https-only false

STORAGE_KEY=$(az storage account keys list --account-name $STORAGE_ACCOUNT --resource-group $NODE_GROUP --query "[0].value")

az storage share create -n job --quota 10 --account-name $STORAGE_ACCOUNT --account-key $STORAGE_KEY

kubectl create secret generic azurefile-secret --from-literal=azurestorageaccountname=$STORAGE_ACCOUNT --from-literal=azurestorageaccountkey=$STORAGE_KEY 
```

## Storage Classes


## Performance Test

https://raw.githubusercontent.com/logdna/dbench/master/dbench.yaml

### NFS

```
$KUBE_NAME-sp
STORAGE_ACCOUNT=$KUBE_NAME"2"
NODE_GROUP=$(az aks show --resource-group $KUBE_GROUP --name $KUBE_NAME --query nodeResourceGroup -o tsv)

az storage account create --resource-group $NODE_GROUP --name $STORAGE_ACCOUNT --location $LOCATION --sku Premium_LRS --kind FileStorage --access-tier hot --https-only false

STORAGE_KEY=$(az storage account keys list --account-name $STORAGE_ACCOUNT --resource-group $NODE_GROUP --query "[0].value")

kubectl create secret generic azure-secret --from-literal accountname=$STORAGE_ACCOUNT --from-literal accountkey="$STORAGE_KEY" --type=Opaque

cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azurefiledemo
provisioner: kubernetes.io/azure-file
parameters:
  skuName: Standard_LRS
  storageAccount: dzprivate1
EOF

cat <<EOF | kubectl apply -f -
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: dbench-pv-claim-net1
spec:
  storageClassName: azurefiledemo
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
EOF

cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azurefile-csi-net
provisioner: file.csi.azure.com
parameters:
  storageAccount: $STORAGE_ACCOUNT
  resourceGroup: $KUBE_GROUP 
reclaimPolicy: Delete
volumeBindingMode: Immediate
EOF

cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azurefile-csi-large
provisioner: file.csi.azure.com
parameters:
  storageAccount: $STORAGE_ACCOUNT
  shareName: large
reclaimPolicy: Delete
volumeBindingMode: Immediate
EOF

cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azurefile-csi-nfs
provisioner: file.csi.azure.com
parameters:
  resourceGroup: $NODE_GROUP 
  storageAccount: $STORAGE_ACCOUNT
  protocol: nfs
  fsType: nfs
EOF

cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azurefile-csi-nfs
provisioner: file.csi.azure.com
parameters:
  resourceGroup: kub_ter_a_m_csisecurity_csisecurity_nodes_eastus 
  storageAccount: dzpremium1
  protocol: nfs
  fsType: nfs
  csi.storage.k8s.io/provisioner-secret-name: azure-secret
  csi.storage.k8s.io/provisioner-secret-namespace: default
  csi.storage.k8s.io/node-stage-secret-name: azure-secret
  csi.storage.k8s.io/node-stage-secret-namespace: default
  csi.storage.k8s.io/controller-expand-secret-name: azure-secret
  csi.storage.k8s.io/controller-expand-secret-namespace: default
EOF

cat <<EOF | kubectl apply -f -
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: dbench-pv-claim-net1
spec:
  storageClassName: azurefile-csi-net
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
EOF

cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: dbench
spec:
  template:
    spec:
      containers:
      - name: dbench
        image: denniszielke/dbench:latest
        imagePullPolicy: Always
        env:
          - name: DBENCH_MOUNTPOINT
            value: /data
          # - name: DBENCH_QUICK
          #   value: "yes"
          # - name: FIO_SIZE
          #   value: 1G
          # - name: FIO_OFFSET_INCREMENT
          #   value: 256M
          # - name: FIO_DIRECT
          #   value: "0"
        volumeMounts:
        - name: dbench-pv
          mountPath: /data
      restartPolicy: Never
      volumes:
      - name: dbench-pv
        persistentVolumeClaim:
          claimName: dbench-pv-claim-nfs
  backoffLimit: 4
EOF

cat <<EOF | kubectl apply -f -
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: dbench-pv-claim-nfs
spec:
  storageClassName: azurefile-csi-large
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100Ti
EOF

cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: dbench
spec:
  template:
    spec:
      containers:
      - name: dbench
        image: denniszielke/dbench:latest
        imagePullPolicy: Always
        env:
          - name: DBENCH_MOUNTPOINT
            value: /data
          # - name: DBENCH_QUICK
          #   value: "yes"
          # - name: FIO_SIZE
          #   value: 1G
          # - name: FIO_OFFSET_INCREMENT
          #   value: 256M
          # - name: FIO_DIRECT
          #   value: "0"
        volumeMounts:
        - name: dbench-pv
          mountPath: /data
      restartPolicy: Never
      volumes:
      - name: dbench-pv
        persistentVolumeClaim:
          claimName: dbench-pv-claim-nfs
  backoffLimit: 4
EOF

cat <<EOF | kubectl apply -f -
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: azurefile-csi-nfs-test
provisioner: file.csi.azure.com
parameters:
  storageAccount: dzpremium1
  protocol: nfs  # use "fsType: nfs" in v0.8.0
reclaimPolicy: Delete
volumeBindingMode: Immediate
allowVolumeExpansion: true
EOF

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: statefulset-azurefile
  labels:
    app: nginx
spec:
  serviceName: statefulset-azurefile
  replicas: 1
  template:
    metadata:
      labels:
        app: nginx
    spec:
      nodeSelector:
        "kubernetes.io/os": linux
      containers:
        - name: statefulset-azurefile
          image: mcr.microsoft.com/oss/nginx/nginx:1.17.3-alpine
          command:
            - "/bin/sh"
            - "-c"
            - while true; do echo $(date) >> /mnt/azurefile/outfile; sleep 1; done
          volumeMounts:
            - name: persistent-storage
              mountPath: /mnt/azurefile
  updateStrategy:
    type: RollingUpdate
  selector:
    matchLabels:
      app: nginx
  volumeClaimTemplates:
    - metadata:
        name: persistent-storage
        annotations:
          volume.beta.kubernetes.io/storage-class: azurefile-csi-nfs-test
      spec:
        accessModes: ["ReadWriteMany"]
        resources:
          requests:
            storage: 100Gi
EOF
```

### Files CSI

```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: dbench-pv-claim-csi-files
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 100Gi
  storageClassName: azurefile-csi
EOF

cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: dbench
spec:
  template:
    spec:
      containers:
      - name: dbench
        image: denniszielke/dbench:latest
        imagePullPolicy: Always
        env:
          - name: DBENCH_MOUNTPOINT
            value: /data
          # - name: DBENCH_QUICK
          #   value: "yes"
          # - name: FIO_SIZE
          #   value: 1G
          # - name: FIO_OFFSET_INCREMENT
          #   value: 256M
          # - name: FIO_DIRECT
          #   value: "0"
        volumeMounts:
        - name: dbench-pv
          mountPath: /data
      restartPolicy: Never
      volumes:
      - name: dbench-pv
        persistentVolumeClaim:
          claimName: dbench-pv-claim-csi-files
  backoffLimit: 4
EOF
```

### Files 


```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: dbench-pv-claim-files
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 100Gi
  storageClassName: azurefile
EOF

cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: dbench
spec:
  template:
    spec:
      containers:
      - name: dbench
        image: denniszielke/dbench:latest
        imagePullPolicy: Always
        env:
          - name: DBENCH_MOUNTPOINT
            value: /data
          # - name: DBENCH_QUICK
          #   value: "yes"
          # - name: FIO_SIZE
          #   value: 1G
          # - name: FIO_OFFSET_INCREMENT
          #   value: 256M
          # - name: FIO_DIRECT
          #   value: "0"
        volumeMounts:
        - name: dbench-pv
          mountPath: /data
      restartPolicy: Never
      volumes:
      - name: dbench-pv
        persistentVolumeClaim:
          claimName: dbench-pv-claim-files
  backoffLimit: 4
EOF
```

### Files CSI Premium

```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: dbench-pv-claim-csi-prem-files
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 100Gi
  storageClassName: azurefile-csi-premium
EOF

cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: dbench
spec:
  template:
    spec:
      containers:
      - name: dbench
        image: denniszielke/dbench:latest
        imagePullPolicy: Always
        env:
          - name: DBENCH_MOUNTPOINT
            value: /data
          # - name: DBENCH_QUICK
          #   value: "yes"
          # - name: FIO_SIZE
          #   value: 1G
          # - name: FIO_OFFSET_INCREMENT
          #   value: 256M
          # - name: FIO_DIRECT
          #   value: "0"
        volumeMounts:
        - name: dbench-pv
          mountPath: /data
      restartPolicy: Never
      volumes:
      - name: dbench-pv
        persistentVolumeClaim:
          claimName: dbench-pv-claim-csi-prem-files
  backoffLimit: 4
EOF
```
### Premium Files

```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: dbench-pv-claim-prem-files
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 100Gi
  storageClassName: azurefile-premium
EOF

cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: dbench
spec:
  template:
    spec:
      containers:
      - name: dbench
        image: denniszielke/dbench:latest
        imagePullPolicy: Always
        env:
          - name: DBENCH_MOUNTPOINT
            value: /data
          # - name: DBENCH_QUICK
          #   value: "yes"
          # - name: FIO_SIZE
          #   value: 1G
          # - name: FIO_OFFSET_INCREMENT
          #   value: 256M
          # - name: FIO_DIRECT
          #   value: "0"
        volumeMounts:
        - name: dbench-pv
          mountPath: /data
      restartPolicy: Never
      volumes:
      - name: dbench-pv
        persistentVolumeClaim:
          claimName: dbench-pv-claim-prem-files
  backoffLimit: 4
EOF
```
### Managed Premium Disk CSI

```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: dbench-pv-claim-premium-csi-disk
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 100Gi
  storageClassName: managed-csi-premium
EOF

cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: dbench
spec:
  template:
    spec:
      containers:
      - name: dbench
        image: logdna/dbench:latest
        imagePullPolicy: Always
        env:
          - name: DBENCH_MOUNTPOINT
            value: /data
          # - name: DBENCH_QUICK
          #   value: "yes"
          # - name: FIO_SIZE
          #   value: 1G
          # - name: FIO_OFFSET_INCREMENT
          #   value: 256M
          # - name: FIO_DIRECT
          #   value: "0"
        volumeMounts:
        - name: dbench-pv
          mountPath: /data
      restartPolicy: Never
      volumes:
      - name: dbench-pv
        persistentVolumeClaim:
          claimName: dbench-pv-claim-premium-csi-disk
  backoffLimit: 4
EOF
```
### Managed Premium

```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: dbench-pv-claim-premium-disk
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 100Gi
  storageClassName: managed-premium
EOF

cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: dbench
spec:
  template:
    spec:
      containers:
      - name: dbench
        image: logdna/dbench:latest
        imagePullPolicy: Always
        env:
          - name: DBENCH_MOUNTPOINT
            value: /data
          # - name: DBENCH_QUICK
          #   value: "yes"
          # - name: FIO_SIZE
          #   value: 1G
          # - name: FIO_OFFSET_INCREMENT
          #   value: 256M
          # - name: FIO_DIRECT
          #   value: "0"
        volumeMounts:
        - name: dbench-pv
          mountPath: /data
      restartPolicy: Never
      volumes:
      - name: dbench-pv
        persistentVolumeClaim:
          claimName: dbench-pv-claim-premium-disk
  backoffLimit: 4
EOF

kubectl logs -f job/dbench
```

## Storage NFS 3

https://github.com/kubernetes-sigs/blob-csi-driver/tree/master/deploy/example/nfs

```
curl -skSL https://raw.githubusercontent.com/kubernetes-sigs/blob-csi-driver/master/deploy/install-driver.sh | bash -s master --

kubectl -n kube-system get pod -o wide -l app=csi-blob-controller
kubectl -n kube-system get pod -o wide -l app=csi-blob-node

curl -skSL https://raw.githubusercontent.com/kubernetes-sigs/blob-csi-driver/master/deploy/uninstall-driver.sh | bash -s master --


kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/blob-csi-driver/master/deploy/v1.0.0/rbac-csi-blob-node.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/blob-csi-driver/master/deploy/v1.0.0/rbac-csi-blob-controller.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/blob-csi-driver/master/deploy/v1.0.0/csi-blob-node.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/blob-csi-driver/master/deploy/v1.0.0/csi-blob-controller.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/blob-csi-driver/master/deploy/v1.0.0/csi-blob-driver.yaml

cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: blob-nfs
provisioner: blob.csi.azure.com
parameters:
  resourceGroup: kub_ter_a_s_store3  # optional, only set this when storage account is not in the same resource group as agent node
  storageAccount: dzstore3
  protocol: nfs
EOF

cat <<EOF | kubectl apply -f -
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: statefulset-blob
  labels:
    app: dbench
spec:
  serviceName: dbench
  replicas: 1
  template:
    metadata:
      labels:
        app: dbench
    spec:
      nodeSelector:
        "kubernetes.io/os": linux
      containers:
        - name: dbench
          image: denniszielke/dbench:latest
          env:
            - name: DBENCH_MOUNTPOINT
              value: /mnt/blob
          volumeMounts:
            - name: persistent-storage
              mountPath: /mnt/blob
  updateStrategy:
    type: RollingUpdate
  selector:
    matchLabels:
      app: dbench
  volumeClaimTemplates:
    - metadata:
        name: persistent-storage
        annotations:
          volume.beta.kubernetes.io/storage-class: blob-nfs
      spec:
        accessModes: ["ReadWriteMany"]
        resources:
          requests:
            storage: 100Gi
EOF

cat <<EOF | kubectl apply -f -
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: statefulset-blob
  labels:
    app: nginx
spec:
  serviceName: statefulset-blob
  replicas: 1
  template:
    metadata:
      labels:
        app: nginx
    spec:
      nodeSelector:
        "kubernetes.io/os": linux
      containers:
        - name: statefulset-blob
          image: mcr.microsoft.com/oss/nginx/nginx:1.17.3-alpine
          command:
            - "/bin/sh"
            - "-c"
            - while true; do echo $(date) >> /mnt/blob/outfile; sleep 1; done
          volumeMounts:
            - name: persistent-storage
              mountPath: /mnt/blob
  updateStrategy:
    type: RollingUpdate
  selector:
    matchLabels:
      app: nginx
  volumeClaimTemplates:
    - metadata:
        name: persistent-storage
        annotations:
          volume.beta.kubernetes.io/storage-class: blob-nfs
      spec:
        accessModes: ["ReadWriteMany"]
        resources:
          requests:
            storage: 100Gi
EOF

apiVersion: batch/v1
kind: Job
metadata:
  name: dbench
spec:
  template:
    spec:
      containers:
      - name: dbench
        image: logdna/dbench:latest
        imagePullPolicy: Always
        env:
          - name: DBENCH_MOUNTPOINT
            value: /data
          # - name: DBENCH_QUICK
          #   value: "yes"
          # - name: FIO_SIZE
          #   value: 1G
          # - name: FIO_OFFSET_INCREMENT
          #   value: 256M
          # - name: FIO_DIRECT
          #   value: "0"
      volumeClaimTemplates:
      - metadata:
          name: persistent-storage
          annotations:
            volume.beta.kubernetes.io/storage-class: blob-nfs
        spec:
          accessModes: ["ReadWriteMany"]
          resources:
            requests:
              storage: 100Gi
  backoffLimit: 4
EOF
```

# Results - 1.17.X

# westeurope csi azure files
Random Read/Write IOPS: 643/1016. BW: 71.7MiB/s / 70.1MiB/s
Average Latency (usec) Read/Write: 20.49/
Sequential Read/Write: 69.7MiB/s / 74.6MiB/s
Mixed Random Read/Write IOPS: 738/245

# westeurope azure files 
Random Read/Write IOPS: 727/1019. BW: 75.7MiB/s / 68.3MiB/s
Average Latency (usec) Read/Write: 18.14/
Sequential Read/Write: 74.6MiB/s / 73.9MiB/s
Mixed Random Read/Write IOPS: 756/246


# eastus csi nfs files
Random Read/Write IOPS: 303/290. BW: 38.9MiB/s / 38.8MiB/s
Average Latency (usec) Read/Write: 13.70/13.23
Sequential Read/Write: 305MiB/s / 177MiB/s
Mixed Random Read/Write IOPS: 157/55

Random Read/Write IOPS: 303/292. BW: 38.9MiB/s / 38.8MiB/s
Average Latency (usec) Read/Write: 13.49/13.33
Sequential Read/Write: 313MiB/s / 171MiB/s
Mixed Random Read/Write IOPS: 161/52

# eastus csi azure files
Random Read/Write IOPS: 997/1012. BW: 118MiB/s / 71.4MiB/s
Average Latency (usec) Read/Write: /
Sequential Read/Write: 67.4MiB/s / 75.2MiB/s
Mixed Random Read/Write IOPS: 770/256

Random Read/Write IOPS: 796/1016. BW: 80.3MiB/s / 82.8MiB/s
Average Latency (usec) Read/Write: /
Sequential Read/Write: 69.4MiB/s / 84.9MiB/s
Mixed Random Read/Write IOPS: 755/248

# eastus azure files
Random Read/Write IOPS: 1013/1006. BW: 125MiB/s / 69.6MiB/s
Average Latency (usec) Read/Write: /
Sequential Read/Write: 67.9MiB/s / 71.8MiB/s
Mixed Random Read/Write IOPS: 771/251

Random Read/Write IOPS: 749/1015. BW: 79.4MiB/s / 85.3MiB/s
Average Latency (usec) Read/Write: /
Sequential Read/Write: 66.7MiB/s / 85.5MiB/s
Mixed Random Read/Write IOPS: 728/251

# eastus csi premium files
Random Read/Write IOPS: 302/304. BW: 38.6MiB/s / 37.9MiB/s
Average Latency (usec) Read/Write: 13.28/13.19
Sequential Read/Write: 218MiB/s / 68.9MiB/s
Mixed Random Read/Write IOPS: 211/72

Random Read/Write IOPS: 306/290. BW: 38.8MiB/s / 37.3MiB/s
Average Latency (usec) Read/Write: 13.22/13.74
Sequential Read/Write: 305MiB/s / 84.9MiB/s
Mixed Random Read/Write IOPS: 164/54

# eastus premium files
Random Read/Write IOPS: 303/303. BW: 38.3MiB/s / 37.7MiB/s
Average Latency (usec) Read/Write: 13.36/13.09
Sequential Read/Write: 265MiB/s / 72.8MiB/s
Mixed Random Read/Write IOPS: 183/60



# Results - 1.18.8

# eastus csi nfs files
Random Read/Write IOPS: 303/289. BW: 38.8MiB/s / 38.8MiB/s
Average Latency (usec) Read/Write: 13.47/13.48
Sequential Read/Write: 293MiB/s / 176MiB/s
Mixed Random Read/Write IOPS: 164/53

# increased storage to 10TB
Random Read/Write IOPS: 11.2k/10.7k. BW: 192MiB/s / 180MiB/s
Average Latency (usec) Read/Write: 1973.15/3883.61
Sequential Read/Write: 326MiB/s / 180MiB/s
Mixed Random Read/Write IOPS: 7049/2340

# eastus csi azure files
Random Read/Write IOPS: 594/1024. BW: 83.8MiB/s / 128MiB/s
Average Latency (usec) Read/Write: /
Sequential Read/Write: 125MiB/s / 170MiB/s
Mixed Random Read/Write IOPS: 761/255

# eastus azure files

Random Read/Write IOPS: 782/1015. BW: 98.3MiB/s / 128MiB/s
Average Latency (usec) Read/Write: /
Sequential Read/Write: 132MiB/s / 184MiB/s
Mixed Random Read/Write IOPS: 768/252

# eastus csi premium files

Random Read/Write IOPS: 307/296. BW: 38.8MiB/s / 38.9MiB/s
Average Latency (usec) Read/Write: 13.28/13.71
Sequential Read/Write: 228MiB/s / 179MiB/s
Mixed Random Read/Write IOPS: 192/65

# increased storage to 10TB
Random Read/Write IOPS: 18.9k/13.5k. BW: 219MiB/s / 181MiB/s
Average Latency (usec) Read/Write: 2681.44/1879.12
Sequential Read/Write: 232MiB/s / 184MiB/s
Mixed Random Read/Write IOPS: 11.7k/3849

# eastus premium files

https://docs.microsoft.com/en-us/azure/storage/files/storage-troubleshooting-files-nfs

https://github.com/kubernetes-sigs/azurefile-csi-driver
