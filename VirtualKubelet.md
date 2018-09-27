# Installing virtual kubelet

https://github.com/virtual-kubelet/virtual-kubelet/tree/master/providers/azure

0. Variables
```
KUBE_GROUP=
KUBE_NAME=
LOCATION=westeurope
ACI_GROUP=aci-group
```

1. create aci resource group
az group create --name $ACI_GROUP --location $LOCATION

az aks install-connector --resource-group $KUBE_GROUP --name $KUBE_NAME --aci-resource-group $ACI_GROUP


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

kubectl delete pods,services -l app=hello-app

kubectl delete pods,services -l pod-template-hash=916745872