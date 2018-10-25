# Installing virtual kubelet

https://github.com/virtual-kubelet/virtual-kubelet/tree/master/providers/azure

0. Variables
```
KUBE_GROUP=kubes-aci
KUBE_NAME=dzkubaci
LOCATION=westeurope
ACI_GROUP=aci-group
```

1. create aci resource group
```
az group create --name $ACI_GROUP --location $LOCATION
```

2. install connector
```
az aks install-connector --resource-group $KUBE_GROUP --name $KUBE_NAME --aci-resource-group $ACI_GROUP
 
az aks enable-addons \
    --resource-group $KUBE_GROUP \
    --name $KUBE_NAME \
    --addons virtual-node \
    --subnet-name acinet

az aks disable-addons --resource-group $KUBE_GROUP --name $KUBE_NAME –-add-ons virtual-nodes --os-type both
```

3. schedule pod on virtual node

```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: helloworld1
spec:
  containers:
  - image: microsoft/aci-helloworld
    imagePullPolicy: Always
    name: helloworld
    resources:
      requests:
        memory: 1G
        cpu: 1
    ports:
    - containerPort: 80
      name: http
      protocol: TCP
    - containerPort: 443
      name: https
  dnsPolicy: ClusterFirst
  nodeSelector:
    kubernetes.io/role: agent
    beta.kubernetes.io/os: linux
    type: virtual-kubelet
  tolerations:
  - key: virtual-kubelet.io/provider
    operator: Exists
  - key: azure.com/aci
    effect: NoSchedule
EOF
```

```
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1beta1
kind: Deployment
metadata:
  name: aci-helloworld
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: aci-helloworld
    spec:
      containers:
      - name: aci-helloworld
        image: microsoft/aci-helloworld
        ports:
        - containerPort: 80
      nodeSelector:
        kubernetes.io/hostname: virtual-node-aci-linux
      tolerations:
      - key: virtual-kubelet.io/provider
        operator: Equal
        value: azure
        effect: NoSchedule
EOF
```
4. clean up
```
kubectl delete pods,services -l app=hello-app

kubectl delete pods,services -l pod-template-hash=916745872
```