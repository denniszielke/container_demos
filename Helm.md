# Installing helm and tiller
https://github.com/kubernetes/helm

Install helm
wget https://storage.googleapis.com/kubernetes-helm/helm-v2.6.1-linux-amd64.tar.gz
tar -zxvf helm-v2.6.1-linux-amd64.tar.gz
sudo mv linux-amd64/helm /usr/local/bin/helm

Install tiller and upgrade tiller
```
helm

helm init
echo "Upgrading tiller..."
helm init --upgrade
echo "Upgrading chart repo..."
helm repo update
```

If you are on 2.5.1 and want explicitly upgrade to 2.6.1:
```
export TILLER_TAG=v2.6.1
kubectl --namespace=kube-system set image deployments/tiller-deploy tiller=gcr.io/kubernetes-helm/tiller:$TILLER_TAG
```

See all pods (including tiller)
```
kubectl get pods --namespace kube-system
```

reinstall or delte tiller
```
helm reset
```

helm install stable/mysql
https://kubeapps.com/