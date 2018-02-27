# Installing Grafana in AKS

0. Define variables
```
Environment Variables
SUBSCRIPTION_ID=""
KUBE_GROUP="kubs"
KUBE_NAME="dzkub8"
LOCATION="eastus"
STORAGE_ACCOUNT="dzgrafstor"
STORAGE_ACCOUNT_KEY=""
```

## Prerequisites
- Helm
- Storage Class and persistent storage claim

## Set up storage

1. Create storage account
```
az storage account create --resource-group  MC_$(echo $KUBE_GROUP)_$(echo $KUBE_NAME)_$(echo $LOCATION) --name $STORAGE_ACCOUNT --location $LOCATION --sku Standard_LRS
```
  
## Deploy grafana with local mysql

1. Deploy all in one

```
kubectl create -f grafana-mysql-sidecar.yaml
```


Cleanup
```
kubectl delete deployment grafanamysql
kubectl delete pv pv-mysql
kubectl delete pvc mysql-db-claim
kubectl delete sc sc-azure-file
```

## Configure Grafana install via helm

1. Search for helm package
```
helm search grafana
```

2. Check the configuration
https://github.com/kubernetes/charts/tree/master/stable/grafana

```
helm inspect stable/grafana
```

and the configuration values
```
helm inspect values stable/grafana
```

3. Install grafana via Helm
```
helm install --name my-eig stable/grafana --set server.service.type=LoadBalancer --set server.persistentVolume.storageClass=azurefile --set server.setDatasource.enabled=false --set server.persistentVolume.existingClaim=pvc-azurefile
```

4. Get password
```
kubectl get secret --namespace default my-grafana-grafana -o jsonpath="{.data.grafana-admin-password}" | base64 --decode ; echo
```

5. Access grafana
```
export SERVICE_IP=$(kubectl get svc --namespace default my-grafana-grafana -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo http://$SERVICE_IP:
```

6. Cleanup
```
helm delete my-eig
```

