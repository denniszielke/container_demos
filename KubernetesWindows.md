# Kubernetes on Windows

Version compatibility in container engine:
https://docs.microsoft.com/en-us/virtualization/windowscontainers/deploy-containers/version-compatibility

Windows walkthrough:
https://github.com/Azure/acs-engine/blob/master/docs/kubernetes/windows.md#supported-windows-versions

customizing windows deployments:
https://github.com/Azure/acs-engine/blob/master/docs/kubernetes/windows-details.md#customizing-windows-deployments


## create mixed cluster

set variables
```
KUBE_GROUP="dz-win-1803"
KUBE_NAME="dz-win-1803"
LOCATION="northeurope"
```

create resource group
```
az group create -n $KUBE_GROUP -l $LOCATION
```

create arm template
```
./acs-engine generate acseng-1803.json 
```

deploy arm template
```
az group deployment create \
    --name $KUBE_NAME \
    --resource-group $KUBE_GROUP \
    --template-file "_output/$KUBE_NAME/azuredeploy.json" \
    --parameters "_output/$KUBE_NAME/azuredeploy.parameters.json"
```

set the kubeconfig
```
export KUBECONFIG=`pwd`/_output/$KUBE_NAME/kubeconfig/kubeconfig.northeurope.json
```

check nodes
```
kubectl get node -l beta.kubernetes.io/os=windows
kubectl get node -l beta.kubernetes.io/os=linux
```

if you see the following error message
error: unable to forward port because pod is not running. Current status=Pending
create a binding for the dashboard account
```
kubectl create clusterrolebinding kubernetes-dashboard --clusterrole=cluster-admin --serviceaccount=kube-system:kubernetes-dashboard
```


## Setting up ingress in a mixed cluster
https://github.com/Azure/acs-engine/blob/master/docs/kubernetes/mixed-cluster-ingress.md

init helm only on linux boxes
```
helm init --upgrade --node-selectors "beta.kubernetes.io/os=linux"

helm install --name nginx-ingress \
    --set controller.nodeSelector."beta\.kubernetes\.io\/os"=linux \
    --set defaultBackend.nodeSelector."beta\.kubernetes\.io\/os"=linux \
    --set rbac.create=true \
    stable/nginx-ingress

```

create hello world app
```
kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/aci-helloworld/iis-win-1803.yaml
```

create ingress
```
kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/aci-helloworld/ingress-win-1803.yaml
```

## Additional

getting logs from windows agents:

https://github.com/andyzhangx/Demo/tree/master/debug#q-how-to-get-k8s-kubelet-logs-on-windows-agent

using storage in windows agents:
https://github.com/andyzhangx/demo/tree/master/windows
