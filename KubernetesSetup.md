# Create container cluster
https://docs.microsoft.com/en-us/azure/container-service/kubernetes/container-service-kubernetes-walkthrough

0. Variables
```
SUBSCRIPTION_ID=""
KUBE_GROUP="kubeacs"
KUBE_NAME="dzkubeacs"
LOCATION="northeurope"
```

Select subscription
```
az account set --subscription $SUBSCRIPTION_ID
```

1. Create the resource group
```
az group create -n $KUBE_GROUP -l $LOCATION
```

2. Create the acs cluster
```
az acs create --name $KUBE_NAME --resource-group $KUBE_GROUP --orchestrator-type Kubernetes --dns-prefix $KUBE_NAME --generate-ssh-keys
```

3. Export the kubectrl credentials files
```
az acs kubernetes get-credentials --resource-group=$KUBE_GROUP --name=$KUBE_NAME
```

or If you are not using the Azure Cloud Shell and don’t have the Kubernetes client kubectl, run 
```
sudo az acs kubernetes install-cli

scp azureuser@$KUBE_NAMEmgmt.westeurope.cloudapp.azure.com:.kube/config $HOME/.kube/config
```

4. Check that everything is running ok
```
kubectl version
kubectl config current-contex
```

Use flag to use context
```
kubectl --kube-context
```

# Deploy pod
https://github.com/Azure/acs-engine/blob/master/docs/kubernetes.md
https://docs.microsoft.com/en-us/azure/container-service/kubernetes/container-service-kubernetes-load-balancing

1. Deploy simplest image and check the yaml configuration
```
kubectl run nginx --image nginx
kubectl get pods -o yaml
```

2.  Change the deployment and expose it as a services
```
kubectl expose deployment nginx --port=80
kubectl get service
kubectl edit svc/nginx
```
`
This will launch VIM - go to position - use "i" to insert and change ClusterIP to LoadBalancer.
Exit CTRL-C edit mode, write and quit with ":wq" 
:syntax off
```
kubectl expose deployments nginx --port=80 --type=LoadBalancer
```

```
kubectl expose rc hello-rc --name-svc --target-port=8080 --type=NodePort service
kubectl create -f ./hello.yml
kubectl expose deployment hello --type="LoadBalancer" --port=80 --target-port=8080

kubectl describe svc hello-svc
```

Check yaml file config
https://kubernetes.io/docs/resources-reference/v1.5/

# Create Azure Container Registry secret in Kubernetes
https://medium.com/devoops-and-universe/your-very-own-private-docker-registry-for-kubernetes-cluster-on-azure-acr-ed6c9efdeb51

```
kubectl create secret docker-registry kuberegistry --docker-server 'myveryownregistry-on.azurecr.io' --docker-username 'username' --docker-password 'password' --docker-email 'example@example.com'

```

or

```
kubectl create secret docker-registry kuberegistry --docker-server $REGISTRY_URL --docker-username $REGISTRY_NAME --docker-password $REGISTRY_PASSWORD --docker-email 'example@example.com'
```


# Deploying additional secrets
https://kubernetes.io/docs/concepts/configuration/secret/

Secrets must be base64 encoded.
echo -n "1f2d1e2e67df" | base64

appinsightsecret.yml
```
apiVersion: v1
kind: Secret
metadata:
  name: appinsightsecret
type: Opaque
data:
  appinsightskey: NG0ODBlLTlmZTEtZmFiZDkyMTdiMzNi
```

Deploy secret to cluster
```
kubectl create -f appinsightsecret.yml
```


# Deploy
https://kubernetes.io/docs/user-guide/kubectl-cheatsheet/

kubectl create -f backend-pod.yml
kubectl create -f backend-svc.yml
kubectl create -f frontend-pod.yml
kubectl create -f frontend-svc.yml
