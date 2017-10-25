# Create container cluster (AKS)
https://docs.microsoft.com/en-us/azure/aks/kubernetes-walkthrough

0. Variables
```
SUBSCRIPTION_ID=""
KUBE_GROUP="kubesaks"
KUBE_NAME="dzkubes"
LOCATION="westus2"
REGISTRY_NAME=""
APPINSIGHTS_KEY=""
```

1. Create the resource group
```
az group create -n $KUBE_GROUP -l $LOCATION
```

2. Create the aks cluster
```
az aks create --resource-group $KUBE_GROUP --name $KUBE_NAME --agent-count 3 --generate-ssh-keys
```

```
az aks show --resource-group $KUBE_GROUP --name $KUBE_NAME
```

3. Export the kubectrl credentials files
```
az aks get-credentials --resource-group=$KUBE_GROUP --name=$KUBE_NAME
```

or If you are not using the Azure Cloud Shell and don’t have the Kubernetes client kubectl, run 
```
az aks install-cli
```

or download the file manually
```
scp azureuser@($KUBE_NAME)mgmt.westeurope.cloudapp.azure.com:.kube/config $HOME/.kube/config
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

5. Activate the kubernetes dashboard
```
az aks browse --resource-group=$KUBE_GROUP --name=$KUBE_NAME
```

5. Create container registr
```
az acr create --resource-group "$KUBE_GROUP" --name "$REGISTRY_NAME" --sku Basic --admin-enabled true
```

# Deploy Secrets
https://kubernetes.io/docs/concepts/configuration/secret/

1. The app needs application insights configured inside the cluster under the name appinsightsecret
```
kubectl create secret generic appinsightsecret --from-literal=appinsightskey=$APPINSIGHTS_KEY
```

or 

Secrets must be base64 encoded  & then deployed secret to cluster
```
echo -n "1f2d1e2e67df" | base64
kubectl create -f appinsightsecret.yml
```

2. The secret for accessing your container registry

```
kubectl create secret docker-registry kuberegistry --docker-server 'myveryownregistry-on.azurecr.io' --docker-username 'username' --docker-password 'password' --docker-email 'example@example.com'

```

or

```
kubectl create secret docker-registry kuberegistry --docker-server $REGISTRY_URL --docker-username $REGISTRY_NAME --docker-password $REGISTRY_PASSWORD --docker-email 'example@example.com'
```

# Deploy everything

kubectl create -f fulldeply.yml

Check status of the deployment
kubectl rollout history deployment/nginx-deployment

Rollback deployment
kubectl rollout undo deployment/nginx-deployment

# Delete everything
```
az group delete -n $KUBE_GROUP
```