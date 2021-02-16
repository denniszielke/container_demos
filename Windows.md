# Kubernetes on Windows

Version compatibility in container engine:
https://docs.microsoft.com/en-us/virtualization/windowscontainers/deploy-containers/version-compatibility

Windows walkthrough:
https://github.com/Azure/acs-engine/blob/master/docs/kubernetes/windows.md#supported-windows-versions

customizing windows deployments:
https://github.com/Azure/acs-engine/blob/master/docs/kubernetes/windows-details.md#customizing-windows-deployments

## Get acs-engine

Download latest release from https://github.com/Azure/acs-engine/releases/tag/v0.26.2

```
wget https://github.com/Azure/acs-engine/releases/download/v0.26.2/acs-engine-v0.26.2-darwin-amd64.tar.gz
tar -zxvf acs-engine-v0.26.2-darwin-amd64.tar.gz
cd acs-engine-v0.26.2-darwin-amd64
```

## create mixed cluster

set variables
```
KUBE_GROUP="dz-win-1709-L"
KUBE_NAME="dz-win-1709-L"
LOCATION="westeurope"
```

create resource group
```
az group create -n $KUBE_GROUP -l $LOCATION
```

get one of the sample templates from https://github.com/Azure/acs-engine/tree/master/examples/windows 
or use these ones 
https://github.com/denniszielke/container_demos/blob/master/aks-engine/acsengvnet-win-1809.json
https://github.com/denniszielke/container_demos/blob/master/aks-engine/acsengvnet-win-1803.json

make sure to set the variables for `SERVICE_PRINCIPAL_ID`, `SERVICE_PRINCIPAL_SECRET` and `YOUR_SSH_KEY` with your own values

create arm template by using the acs-engine json
```
./acs-engine generate acseng-1709-L.json 
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
export KUBECONFIG=`pwd`/_output/$KUBE_NAME/kubeconfig/kubeconfig.westeurope.json
```

check nodes
```
kubectl get node -l beta.kubernetes.io/os=windows -o wide
kubectl get node -l beta.kubernetes.io/os=linux -o wide
```


open the dashboard by opening http://localhost:8081/ui
```
kubectl proxy
```

if you see the following error message
error: unable to forward port because pod is not running. Current status=Pending
create a binding for the dashboard account
```
kubectl create clusterrolebinding kubernetes-dashboard --clusterrole=cluster-admin --serviceaccount=kube-system:kubernetes-dashboard
```

create container registry authentication secret

```
REGISTRY_URL=
REGISTRY_NAME=
REGISTRY_PASSWORD=
kubectl create secret docker-registry mobileregistry --docker-server $REGISTRY_URL --docker-username $REGISTRY_NAME --docker-password $REGISTRY_PASSWORD --docker-email 'example@example.com'
```

## Creating storage for the file share
https://github.com/andyzhangx/demo/tree/master/windows

```
AKS_STORAGE_ACCOUNT_NAME=
AKS_STORAGE_RESOURCE_GROUP=
AKS_STORAGE_KEY=
LOCATION=westeurope
````

create storage account
```
az storage account create --resource-group $AKS_STORAGE_RESOURCE_GROUP --name $AKS_STORAGE_ACCOUNT_NAME --location $LOCATION --sku Standard_LRS

AKS_STORAGE_KEY=$(az storage account keys list --account-name $AKS_STORAGE_ACCOUNT_NAME --resource-group $AKS_STORAGE_RESOURCE_GROUP --query "[0].value")

az storage share create -n www-content --quota 10 --account-name $AKS_STORAGE_ACCOUNT_NAME --account-key $AKS_STORAGE_KEY

az storage share create -n www-configuration --quota 10 --account-name $AKS_STORAGE_ACCOUNT_NAME --account-key $AKS_STORAGE_KEY

az storage share create -n publicweb-content --quota 10 --account-name $AKS_STORAGE_ACCOUNT_NAME --account-key $AKS_STORAGE_KEY

kubectl create secret generic azure-secret --from-literal=azurestorageaccountname=$AKS_STORAGE_ACCOUNT_NAME --from-literal=azurestorageaccountkey=$AKS_STORAGE_KEY
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


## Issues
- AHS VHD https://github.com/Azure/aks-engine/tree/master/vhd/release-notes/aks-windows
- Windows Containers (Pods) does not respect CPU Resources Limits in AKS v 1.17.X https://github.com/kubernetes/kubernetes/pull/86101
- Host Aliases do not work in Windows Container RUN Add-Content -Path C:\Windows\System32\drivers\etc\hosts -Value  https://github.com/kubernetes/kubernetes/issues/91132
- Timezone https://github.com/microsoft/Windows-Containers/issues/15
- AHAB https://docs.microsoft.com/en-us/azure/aks/windows-faq#can-i-use-azure-hybrid-benefit-with-windows-nodes
- Keine Hyper-V Isolated Container
- ContainerD (with Hyper-V)
Windows Containers (Pods) does not respect CPU Resources Limits in AKS v 1.17.X

Setting CPU resource Limits in Windows Container (Pod) yaml files are neglected causing the PODs to starve the node resources, which in turn makes it very hard to roll deployment updates, as there is no room for max surge pods to be deployed.

The issue is fixed in this GitHub pull request and rolled out starting version k8s 1.18.
	
Host Aliases does not work in Windows Containers.

Unexpectedly setting Host Aliases in Windows Pod yaml files will be neglected, according to the following issue raised in GitHub, it is a known issue in Kubernetes, we ended up adding the following command in the docker file to overcome this:

RUN Add-Content -Path C:\Windows\System32\drivers\etc\hosts -Value "<IP>`<Domain>" -Force
	
The need of increased Worker Processes to Increase performance.

We noticed a slowness and a waste of CPU resources, due the fact that each Windows Pod is only running one worker process, we managed to overcome this issue by adding the following line to docker file:

RUN C:\windows\system32\inetsrv\appcmd.exe set apppool "DefaultAppPool" /processModel.maxProcesses:5

Which in turn increased worker processes to 5 wps, and also helped in mitigating the risk of SQL Server backend reaching the limit of 32767 max concurrent connections.
	
Linux nodes taking over the responsibility of In/Out Bandwidth.
	
Environment Variables are not automatically favored over Application configuration files.

Lack of official SMB drivers for mounting PVT based on Caching Servers.
