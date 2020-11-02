

# 

Preview feature GPUDedicatedVHDPreview



KUBE_GROUP="dzscalers"
KUBE_NAME="akspot"
LOCATION="westeurope"
KUBE_VERSION="1.18.6"

az account set --subscription $ENG_SUB_ID

az feature register --namespace "Microsoft.Compute" --name "SharedDisksForPremium"
az feature register --name UseCustomizedContainerRuntime --namespace Microsoft.ContainerService
az feature register --name UseCustomizedUbuntuPreview --namespace Microsoft.ContainerService
az feature register --name GPUDedicatedVHDPreview --namespace Microsoft.ContainerService


az provider register --namespace Microsoft.ContainerService

SERVICE_PRINCIPAL_ID=$(az ad sp create-for-rbac --skip-assignment --name $KUBE_NAME-sp -o json | jq -r '.appId')
echo $SERVICE_PRINCIPAL_ID

SERVICE_PRINCIPAL_SECRET=$(az ad app credential reset --id $SERVICE_PRINCIPAL_ID -o json | jq '.password' -r)
echo $SERVICE_PRINCIPAL_SECRET

az group create -n $KUBE_GROUP -l $LOCATION

az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --vm-set-type VirtualMachineScaleSets --load-balancer-sku standard --kubernetes-version $KUBE_VERSION \
    --node-count 3 --client-secret $SERVICE_PRINCIPAL_SECRET --service-principal $SERVICE_PRINCIPAL_ID --aks-custom-headers CustomizedUbuntu=aks-ubuntu-1804,ContainerRuntime=containerd,UseGPUDedicatedVHD=true

az aks nodepool add -g $KUBE_GROUP --cluster-name $KUBE_NAME -n gpuvhdct --mode user -c 1 --node-vm-size Standard_NC6 --enable-cluster-autoscaler --min-count 0 --max-count 3

az aks nodepool add -g $KUBE_GROUP --cluster-name $KUBE_NAME -n gpuvhdct -c 1 --mode user --node-vm-size Standard_NC6 --aks-custom-headers CustomizedUbuntu=aks-ubuntu-1804,ContainerRuntime=containerd,UseGPUDedicatedVHD=true

az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --vm-set-type VirtualMachineScaleSets --load-balancer-sku standard --kubernetes-version $KUBE_VERSION \
    --node-count 3 --enable-managed-identity 


cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: nvidia-device-plugin-daemonset
  namespace: gpu-resources
spec:
  selector:
    matchLabels:
      name: nvidia-device-plugin-ds
  updateStrategy:
    type: RollingUpdate
  template:
    metadata:
      # Mark this pod as a critical add-on; when enabled, the critical add-on scheduler
      # reserves resources for critical add-on pods so that they can be rescheduled after
      # a failure.  This annotation works in tandem with the toleration below.
      annotations:
        scheduler.alpha.kubernetes.io/critical-pod: ""
      labels:
        name: nvidia-device-plugin-ds
    spec:
      tolerations:
      # Allow this pod to be rescheduled while the node is in "critical add-ons only" mode.
      # This, along with the annotation above marks this pod as a critical add-on.
      - key: CriticalAddonsOnly
        operator: Exists
      - key: nvidia.com/gpu
        operator: Exists
        effect: NoSchedule
      containers:
      - image: nvidia/k8s-device-plugin:1.11
        name: nvidia-device-plugin-ctr
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop: ["ALL"]
        volumeMounts:
          - name: device-plugin
            mountPath: /var/lib/kubelet/device-plugins
      volumes:
        - name: device-plugin
          hostPath:
            path: /var/lib/kubelet/device-plugins
EOF

cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  labels:
    app: samples-tf-mnist-demo
  name: samples-tf-mnist-demo
spec:
  template:
    metadata:
      labels:
        app: samples-tf-mnist-demo
    spec:
      containers:
      - name: samples-tf-mnist-demo
        image: microsoft/samples-tf-mnist-demo:gpu
        args: ["--max_steps", "500"]
        imagePullPolicy: IfNotPresent
        resources:
          limits:
           nvidia.com/gpu: 1
      restartPolicy: OnFailure
EOF

kubectl get pods --selector app=samples-tf-mnist-demo


## aci 



az aks enable-addons \
    --resource-group $KUBE_GROUP \
    --name $KUBE_NAME \
    --addons virtual-node \
    --subnet-name aci-2-subnet

STORAGE_ACCOUNT=$KUBE_NAME

NODE_GROUP=$(az aks show --resource-group $KUBE_GROUP --name $KUBE_NAME --query nodeResourceGroup -o tsv)

az storage account create --resource-group  $NODE_GROUP --name $STORAGE_ACCOUNT --location $LOCATION --sku Standard_LRS --kind StorageV2 --access-tier hot --https-only false

STORAGE_KEY=$(az storage account keys list --account-name $STORAGE_ACCOUNT --resource-group $NODE_GROUP --query "[0].value")

az storage share create -n job --quota 10 --account-name $STORAGE_ACCOUNT --account-key $STORAGE_KEY

kubectl create secret generic azurefile-secret --from-literal=azurestorageaccountname=$STORAGE_ACCOUNT --from-literal=azurestorageaccountkey=$STORAGE_KEY 



# Create a storage account

STORAGE_ACCOUNT=dzkubv1
az storage account create -n $STORAGE_ACCOUNT -g $KUBE_GROUP -l $LOCATION --sku Standard_LRS

# Export the connection string as an environment variable, this is used when creating the Azure file share
export AZURE_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string -n $STORAGE_ACCOUNT -g $KUBE_GROUP -o tsv)

# Create the file share
az storage share create -n $STORAGE_ACCOUNT --connection-string $AZURE_STORAGE_CONNECTION_STRING

# Get storage account key
STORAGE_KEY=$(az storage account keys list --resource-group $KUBE_GROUP --account-name $STORAGE_ACCOUNT --query "[0].value" -o tsv)

# Echo storage account name and key
echo Storage account name: $STORAGE_ACCOUNT
echo Storage account key: $STORAGE_KEY

kubectl create secret generic azurefilev1-secret --from-literal=azurestorageaccountname=$STORAGE_ACCOUNT --from-literal=azurestorageaccountkey=$STORAGE_KEY
