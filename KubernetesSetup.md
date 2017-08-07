# Create container cluster
https://docs.microsoft.com/en-us/azure/container-service/kubernetes/container-service-kubernetes-walkthrough

1. Create the resource group
```
KUBE_GROUP="KubesDemo4"
KUBE_NAME="dzkube4"
az group create -n $KUBE_GROUP -l "westeurope"
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
```
kubectl expose deployments nginx --port=80 --type=LoadBalancer
```

```
kubectl expose rc hello-rc --name-svc --target-port=8080 --type=NodePort service
kubectl create -f ./hello.yml
kubectl expose deployment hello --type="LoadBalancer" --port=80 --target-port=8080

kubectl describe svc hello-svc
```

# Create Azure Container Registry secret in Kubernetes
https://medium.com/devoops-and-universe/your-very-own-private-docker-registry-for-kubernetes-cluster-on-azure-acr-ed6c9efdeb51

```
kubectl create secret docker-registry registrykey --docker-server myveryownregistry-on.azurecr.io', '--docker-username', username, '--docker-password', password, '--docker-email example@example.com']

```

# Kubernetes ingress controller
https://kubernetes.io/docs/concepts/services-networking/ingress/

https://blogs.technet.microsoft.com/livedevopsinjapan/2017/02/28/configure-nginx-ingress-controller-for-tls-termination-on-kubernetes-on-azure-2/

```
git clone https://github.com/kubernetes/ingress.git
cd ingress/examples/deployment/nginx
kubectl apply -f default-backend.yaml
kubectl -n kube-system get po
kubectl apply -f nginx-ingress-controller.yaml
kubectl -n kube-system get po
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=nginxsvc/O=nginxsvc"
kubectl create secret tls tls-secret --key tls.key --cert tls.crt
kubectl create -f http-svc.yaml
nano http-svc.yaml
kubectl create -f http-svc.yaml
kubectl get service
nano nginx-tls-ingress.yaml
kubectl create -f nginx-tls-ingress.yaml
rm nginx-tls-ingress.yaml
nano nginx-tls-ingress.yaml
kubectl create -f nginx-tls-ingress.yaml
kubectl get rs --namespace kube-system
kubectl expose rs nginx-ingress-controller-2781903634 --port=443 --target-port=443 --name=nginx-ingress-ssl --type=LoadBalancer --namespace kube-system
kubectl get services --namespace kube-system -w
```