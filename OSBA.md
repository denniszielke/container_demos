# Setting up Service Broker
https://docs.microsoft.com/en-us/azure/aks/integrate-azure

0. Define variables
```
SUBSCRIPTION_ID=""
KUBE_GROUP="kubesaks"
KUBE_NAME="dzkubes"
LOCATION="westeurope"
REGISTRY_NAME=""
APPINSIGHTS_KEY=""

OSBA_CLIENT_ID=
OSBA_CLIENT_SECRET=
OSBA_TENANT_ID=
OSBA_SUBSCRIPTION_ID=$SUBSCRIPTION_ID
```
az ad sp create-for-rbac --name "osba_sp"


1. Install service catalog
```
helm repo add svc-cat https://svc-catalog-charts.storage.googleapis.com
helm install svc-cat/catalog --name catalog --namespace catalog --set controllerManager.healthcheck.enabled=false
kubectl get apiservice
```

2. OSBA for Azure
```
helm repo add azure https://kubernetescharts.blob.core.windows.net/azure

az ad sp create-for-rbac --name "osba_sp"

helm install azure/open-service-broker-azure --name osba --namespace osba \
    --set azure.subscriptionId=$OSBA_SUBSCRIPTION_ID \
    --set azure.tenantId=$OSBA_TENANT_ID \
    --set azure.clientId=$OSBA_CLIENT_ID \
    --set azure.clientSecret=$OSBA_CLIENT_SECRET

helm upgrade osba azure/open-service-broker-azure --set logLevel=DEBUG --namespace osba \
    --set azure.subscriptionId=$OSBA_SUBSCRIPTION_ID \
    --set azure.tenantId=$OSBA_TENANT_ID \
    --set azure.clientId=$OSBA_CLIENT_ID \
    --set azure.clientSecret=$OSBA_CLIENT_SECRET
```

3. Install cli
https://github.com/Azure/service-catalog-cli
```
curl -sLO https://servicecatalogcli.blob.core.windows.net/cli/latest/$(uname -s)/$(uname -m)/svcat
chmod +x ./svcat
```

4. install instance and create binding 
https://github.com/Azure/open-service-broker-azure
```
kubectl delete servicebinding my-postgresqldb-binding
```