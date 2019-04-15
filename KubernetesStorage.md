# Using storage in AKS

https://github.com/MicrosoftDocs/azure-docs/blob/master/articles/aks/azure-disks-dynamic-pv.md

0. Define variables
```
SUBSCRIPTION_ID=""
KUBE_GROUP="kubs"
KUBE_NAME="dzkub8"
LOCATION="eastus"
STORAGE_ACCOUNT="dzkubestor"
STORAGE_ACCOUNT_KEY=""
STORAGE_SHARE_WRITE="k8swrite"
STORAGE_SHARE_READ="k8sread"
```

## Prerequisites
- Helm
- Storage Class and persistent storage claim

## Set up storage account

1. Create storage account
```
az storage account create --resource-group  MC_$(echo $KUBE_GROUP)_$(echo $KUBE_NAME)_$(echo $LOCATION) --name $STORAGE_ACCOUNT --location $LOCATION --sku Standard_LRS
```

2. Get Keys (optional for simple deployment with storage in the same resource group)
```
az storage account keys list --account-name $STORAGE_ACCOUNT --resource-group MC_$(echo $KUBE_GROUP)_$(echo $KUBE_NAME)_$(echo $LOCATION)
```
Assign to variable
```
STORAGE_ACCOUNT_KEY=$(az storage account keys list --account-name $STORAGE_ACCOUNT --resource-group MC_$(echo $KUBE_GROUP)_$(echo $KUBE_NAME)_$(echo $LOCATION) --query [0].value)
```

3. Replace {ACCOUNT_NAME} and {STORAGE_ACCOUNT_KEY} in sc-azure.yaml
```
sed -e "s/ACCOUNT_NAME/$STORAGE_ACCOUNT/;  s/STORAGE_ACCOUNT_KEY/$STORAGE_ACCOUNT_KEY/" sc-secret.yaml > scsecret.yaml
```

4. Deploy storage class
```
kubectl create -f sc-azure.yaml
```

## Set up azure file storage

1. Create shares
```
az storage share create --name $STORAGE_SHARE_WRITE --account-name $STORAGE_ACCOUNT 
az storage share create --name $STORAGE_SHARE_READ --account-name $STORAGE_ACCOUNT 
```

2. Replace storage account name in storage class configuration
```
sed -e "s/ACCOUNT_NAME/$STORAGE_ACCOUNT/" sc-azure-file.yaml > scazurefile.yaml
kubectl create -f scazurefile.yaml
```

3. Provision storage class
```
kubectl create -f pvc-azurefile.yaml
```

4. Bring up a pod to use claim and log into it
```
kubectl create -f pod-write-azurefile.yaml
kubectl exec -ti frontend bash
echo "Hallo Welt" > /var/www/html/out.html
exit
kubectl exec frontend env
```

5. Bring up a pod to use an existing share and log into it
```
kubectl create -f pod-read-azurefile.yaml
kubectl exec -ti frontend bash
echo "Hallo Welt" > /var/www/html/out.html
exit
kubectl exec frontend env
```

## Set up azure disk storage
https://kubernetes.io/docs/concepts/storage/storage-classes/#azure-disk

create claim
```
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
```

assign claim
```
cat <<EOF | kubectl apply -f - 
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: nginx-azuredisk
spec:
  replicas: 1
  minReadySeconds: 5
  template:
    metadata:
      labels:
        name: nginx-azuredisk
        app: storage-demo
    spec:
      containers:
      - name: nginx-azuredisk
        image: nginx
        command:
        - "/bin/sh"
        - "-c"
        - while true; do echo $(date) >> /mnt/disk/outfile; sleep 1; done
        volumeMounts:
        - name: disk01
          mountPath: "/mnt/disk"
      volumes:
      - name: disk01
        persistentVolumeClaim:
          claimName: azure-managed-disk 
EOF
```

## Resizin an azure disk
supported as beta since 1.11
https://github.com/kubernetes/kubernetes/pull/64386

make sure that the storage class contains allowVolumeExpansion: true

```
cat <<EOF | kubectl apply -f - 
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: hdd
provisioner: kubernetes.io/azure-disk
parameters:
  skuname: Standard_LRS
  kind: Managed
  cachingmode: None
allowVolumeExpansion: true
provisioner: kubernetes.io/azure-disk
reclaimPolicy: Delete
volumeBindingMode: Immediate
EOF
```

create a claim that is too small

```
cat <<EOF | kubectl apply -f - 
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysmalldisk
spec:
  accessModes:
  - ReadWriteOnce
  storageClassName: hdd
  resources:
    requests:
      storage: 5Gi
EOF
```

create deployment to bind that claim
```
cat <<EOF | kubectl apply -f - 
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: nginx-hdd
spec:
  replicas: 1
  minReadySeconds: 5
  template:
    metadata:
      labels:
        name: nginx-hdd
        app: storage-demo
    spec:
      containers:
      - name: nginx-hdd
        image: nginx
        command:
        - "/bin/sh"
        - "-c"
        - while true; do echo $(date) >> /mnt/disk/outfile; sleep 1; done
        volumeMounts:
        - name: disk02
          mountPath: "/mnt/disk"
      volumes:
      - name: disk02
        persistentVolumeClaim:
          claimName: mysmalldisk
EOF
```

log into the pod and check the disk space
```
POD_NAME=$(kubectl get pod -l name=nginx-hdd -o template --template "{{(index .items 0).metadata.name}}")
kubectl get pvc -o template --template "{{(index .items 0).spec.volumeName}}"

kubectl exec -it $POD_NAME -- /bin/bash

df -h
```

scale down deployment
```
kubectl scale deployment nginx-hdd --replicas=0

KUBE_EDITOR="nano" kubectl edit pvc/mysmalldisk
```

change 5Gi to 10Gi
rescale the deployment
```
kubectl scale deployment nginx-hdd --replicas=1
```

# Manually attach disk

```
az disk create \
  --resource-group $KUBE_GROUP \
  --name myAKSDisk  \
  --size-gb 20 \
  --query id --output tsv
```

```
cat <<EOF | kubectl apply -f - 
apiVersion: v1
kind: Pod
metadata:
  name: mypod
spec:
  containers:
  - image: nginx:1.15.5
    name: mypod
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 250m
        memory: 256Mi
    volumeMounts:
      - name: azure
        mountPath: /mnt/azure
  volumes:
      - name: azure
        azureDisk:
          kind: Managed
          diskName: myAKSDisk
          diskURI: /subscriptions/5abd8123-18f8-427f-a4ae-30bfb82617e5/resourceGroups/dz-k8s-12/providers/Microsoft.Compute/disks/myAKSDisk
EOF
```