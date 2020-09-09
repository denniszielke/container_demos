

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

az aks nodepool add -g $KUBE_GROUP --cluster-name $KUBE_NAME -n gpuvhdct -c 1 --mode user --node-vm-size Standard_NC6 --aks-custom-headers CustomizedUbuntu=aks-ubuntu-1804,ContainerRuntime=containerd,UseGPUDedicatedVHD=true

cat <<EOF | kubectl apply -f -
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