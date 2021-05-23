# Deploy voting app

```
kubectl apply -f https://raw.githubusercontent.com/Azure-Samples/azure-voting-app-redis/master/azure-vote-all-in-one-redis.yaml

kubectl get pod -o wide

kubectl scale --replicas=6 deployment/azure-vote-front
kubectl scale --replicas=4 deployment/azure-vote-back

kubectl autoscale deployment azure-vote-front --cpu-percent=20 --min=20 --max=30

kubectl get hpa

kubectl run -it busybox-replicas --rm --image=busybox -- sh

for i in 1 2 3 4 5; do
wget -q -O- http://azure-vote-front
done

kubectl run -it busybox-replicas --rm --image=busybox -- sh

for i in 1 ... 1000; do \ 
wget -q -O- http://65.52.144.134 \
done
for i in `seq 1 100`; do time curl -s http://40.85.173.109 > /dev/null; done

for i in {1...200} \ do \    curl -q -O- "http://azure-vote-front?i="$i \ done

while true; do sleep 1; curl http://40.85.173.109; echo -e '\n\n\n\n'$(date);done


for i in {1..2000}

wget -q -O- http://65.52.144.134?{1..2000}

```

# Virtual node autoscaling
https://github.com/Azure-Samples/virtual-node-autoscale

```
helm install --name vn-affinity ./charts/vn-affinity-admission-controller

kubectl label namespace default vn-affinity-injection=enabled --overwrite

export VK_NODE_NAME=virtual-node-aci-linux
export INGRESS_EXTERNAL_IP=13.69.125.59
export INGRESS_CLASS_ANNOTATION=nginx

helm install ./charts/online-store --name online-store --set counter.specialNodeName=$VK_NODE_NAME,app.ingress.host=store.$INGRESS_EXTERNAL_IP.nip.io,appInsight.enabled=false,app.ingress.annotations."kubernetes\.io/ingress\.class"=$INGRESS_CLASS_ANNOTATION --namespace store 

kubectl -n kube-system get po nginx-ingress-controller-7db8d69bcc-t5zww -o yaml | grep ingress-class | sed -e 's/.*=//'

helm install stable/grafana --version 1.26.1 --name grafana -f grafana/values.yaml

kubectl get secret --namespace default grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

5D7bs0dkBOxvutbEbpGBHRghxMhCWAuHyyYXawfH

export POD_NAME=$(kubectl get pods --namespace default -l "app=grafana" -o jsonpath="{.items[0].metadata.name}")
kubectl --namespace default port-forward $POD_NAME 3000
open http://localhost:3000

az aks get-credentials --resource-group dzburstdemo2 --name dzburst

export GOPATH=~/go
export PATH=$GOPATH/bin:$PATH
go get -u github.com/rakyll/hey
PUBLIC_IP="store.13.95.228.243.nip.io/"
hey -z 20m http://$PUBLIC_IP
```

# Keda
https://github.com/kedacore/sample-hello-world-azure-functions

```
KEDA_STORAGE=dzmesh33
LOCATION=westeurope

az group create -l $LOCATION -n $KUBE_GROUP
az storage account create --sku Standard_LRS --location $LOCATION -g $KUBE_GROUP -n $KEDA_STORAGE

CONNECTION_STRING=$(az storage account show-connection-string --name $KEDA_STORAGE --query connectionString)

az storage queue create -n js-queue-items --connection-string $CONNECTION_STRING

az storage account show-connection-string --name $KEDA_STORAGE --query connectionString

kubectl create namespace keda-app
helm install --name vn-affinity ./charts/vn-affinity-admission-controller

kubectl label namespace keda vn-affinity-injection=disabled --overwrite

KEDA_NS=keda-app
KEDA_IN=hello-keda

func kubernetes install --namespace $KEDA_NS

func kubernetes deploy --name $KEDA_IN --registry denniszielke --namespace $KEDA_NS --polling-interval 5 --cooldown-period 30

kubectl get ScaledObject $KEDA_IN --namespace $KEDA_NS -o yaml

kubectl delete deploy $KEDA_IN --namespace $KEDA_NS
kubectl delete ScaledObject $KEDA_IN --namespace $KEDA_NS
kubectl delete Secret $KEDA_IN --namespace $KEDA_NS

helm install --name vn-affinity ./charts/vn-affinity-admission-controller
kubectl label namespace default vn-affinity-injection=enabled


helm install ./charts/online-store --name online-store --set counter.specialNodeName=$VK_NODE_NAME,app.ingress.host=store.$INGRESS_EXTERNAL_IP.nip.io,appInsight.enabled=false,app.ingress.annotations."kubernetes\.io/ingress\.class"=$INGRESS_CLASS_ANNOTATION
```

## Cluster autoscaler test

```
kubectl run nginx --image=nginx --requests=cpu=1000m,memory=1024Mi --expose --port=80 --replicas=5
kubectl scale deployment nginx --replicas=10
```


while true; do sleep 1; curl http://10.0.1.14/ping; echo -e '\n\n\n\n'$(date);done

az network lb rule list --lb-name kubernetes-internal --resource-group kub_ter_a_m_scaler2_nodes_westeurope



az network lb rule update  --name a13c54ea6e04e11e984ea82987248e36-ing-4-subnet-TCP-80 --lb-name kubernetes-internal --resource-group kub_ter_a_m_scaler2_nodes_westeurope --enable-tcp-reset true


az network lb rule list --lb-name kubernetes-internal --resource-group kub_ter_a_m_scaler_nodes_westeurope

az network lb rule update  --name a69b6ac41e04e11e98bc46e0d4f805cb-ing-4-subnet-TCP-80 --lb-name kubernetes-internal --resource-group kub_ter_a_m_scaler_nodes_westeurope --enable-tcp-reset true


# Scaling with custom metrics
https://github.com/Azure/azure-k8s-metrics-adapter

```
AKS_GROUP=dzphix_520
AKS_NAME=dzphix-520
BLOB_NAME=dzphinx520
LOCATION=westeurope
AZURE_TENANT_ID=$(az account show --query tenantId -o tsv)
AZURE_SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
AZURE_SUBSCRIPTION_ID=$(az account show --query id -o tsv)


AKS_METRICS_PRINCIPAL_ID=$(az ad sp create-for-rbac -n "$BLOB_NAME-sp" --role "Monitoring Reader" --scopes /subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$AKS_GROUP -o json | jq -r '.appId')
AKS_METRICS_PRINCIPAL_SECRET=$(az ad app credential reset --id $AKS_METRICS_PRINCIPAL_ID -o json | jq '.password' -r)

az storage account create --resource-group $AKS_GROUP --name $BLOB_NAME --location $LOCATION --sku Standard_LRS --output none

STORAGE_KEY=$(az storage account keys list --account-name $BLOB_NAME --resource-group $AKS_GROUP --query "[0].value" -o tsv)

az storage container create -n tfstate --account-name $BLOB_NAME --account-key $STORAGE_KEY --output none

#use values from service principle created above to create secret
kubectl create secret generic azure-k8s-metrics-adapter -n custom-metrics \
  --from-literal=azure-tenant-id=$AZURE_TENANT_ID \
  --from-literal=azure-client-id=$AKS_METRICS_PRINCIPAL_ID  \
  --from-literal=azure-client-secret=$AKS_METRICS_PRINCIPAL_SECRET

kubectl apply -f https://raw.githubusercontent.com/Azure/azure-k8s-metrics-adapter/master/deploy/adapter.yaml

cat <<EOF | kubectl apply -f -
apiVersion: azure.com/v1alpha2
kind: ExternalMetric
metadata:
  name: external-metric-blobs
  namespace: custom-metrics
spec:
  type: azuremonitor
  azure:
    resourceGroup: $AKS_GROUP
    resourceName: 
    resourceProviderNamespace: Microsoft.Storage
    resourceType: storageAccounts/$BLOB_NAME/blobServices
  metric:
    metricName: BlobCount
    aggregation: Total
    filter: BlobType eq 'Block blob'
EOF

kubectl get --raw "/apis/external.metrics.k8s.io/v1beta1" | jq .

kubectl  get --raw "/apis/external.metrics.k8s.io/v1beta1/namespaces/custom-metrics/external-metric-blobs" | jq .


cat <<EOF | kubectl apply -f -
apiVersion: autoscaling/v2beta2
kind: HorizontalPodAutoscaler
metadata:
 name: external-metric-blobs
spec:
 scaleTargetRef:
   apiVersion: apps/v1
   kind: Deployment
   name: consumer
 minReplicas: 1
 maxReplicas: 10
 metrics:
  - type: External
    external:
      metricName: external-metric-blobs
      targetValue: 30
EOF

```

# metrics

```

AKS_GROUP=dzphix_520
AKS_NAME=dzphix-520
BLOB_NAME=dzphinx520
LOCATION=westeurope
AZURE_TENANT_ID=$(az account show --query tenantId -o tsv)
AZURE_SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
AZURE_SUBSCRIPTION_ID=$(az account show --query id -o tsv)


AKS_METRICS_PRINCIPAL_ID=$(az ad sp create-for-rbac -n "$BLOB_NAME-sp" --role "Monitoring Reader" --scopes /subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$AKS_GROUP -o json | jq -r '.appId')
AKS_METRICS_PRINCIPAL_SECRET=$(az ad app credential reset --id $AKS_METRICS_PRINCIPAL_ID -o json | jq '.password' -r)

curl -X POST https://login.microsoftonline.com/$AZURE_TENANT_ID/oauth2/token -F "grant_type=client_credentials" -F "$AKS_METRICS_PRINCIPAL_ID" -F "client_secret=$AKS_METRICS_PRINCIPAL_SECRET" -F "resource=https://monitoring.azure.com/"
```

# Promitor

wget -b https://raw.githubusercontent.com/tomkerkhove/promitor/master/charts/promitor-agent-scraper/values.yaml

https://github.com/tomkerkhove/promitor/blob/master/docs/configuration/v2.x/metrics/blob-storage.md

helm repo add promitor https://charts.promitor.io/

helm upgrade promitor-agent-scraper promitor/promitor-agent-scraper \
               --set azureAuthentication.appId="$AKS_METRICS_PRINCIPAL_ID" \
               --set azureAuthentication.appKey="$AKS_METRICS_PRINCIPAL_SECRET" \
               --set azureMetadata.tenantId="$AZURE_TENANT_ID" \
               --set azureMetadata.subscriptionId="$AZURE_SUBSCRIPTION_ID" \
               --set azureMetadata.resourceGroupName="$AKS_GROUP" \
               --values values.yaml --install

helm delete promitor-agent-scraper

export POD_NAME=$(kubectl get pods --namespace default -l "app=promitor-agent-scraper,release=promitor-agent-scraper" -o jsonpath="{.items[0].metadata.name}")

kubectl port-forward --namespace default $POD_NAME 8080:8080

http://0.0.0.0:8080/metrics

```


# keda


```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: azure-monitor-secrets
data:
  activeDirectoryClientId: $AKS_METRICS_PRINCIPAL_ID
  activeDirectoryClientPassword: $AKS_METRICS_PRINCIPAL_SECRET
---
apiVersion: keda.k8s.io/v1alpha1
kind: TriggerAuthentication
metadata: 
  name: azure-monitor-trigger-auth
spec:
  secretTargetRef:
    - parameter: activeDirectoryClientId
      name: azure-monitor-secrets
      key: activeDirectoryClientId
    - parameter: activeDirectoryClientPassword
      name: azure-monitor-secrets
      key: activeDirectoryClientPassword
---
apiVersion: keda.k8s.io/v1alpha1
kind: ScaledObject
metadata:
  name: azure-monitor-scaler
  labels:
    app: azure-monitor-example
spec:
  scaleTargetRef:
    deploymentName: azure-monitor-example
  minReplicaCount: 1
  maxReplicaCount: 10
  triggers:
  - type: azure-monitor
    metadata:
      resourceURI: Microsoft.ContainerService/managedClusters/azureMonitorCluster 
      tenantId: $AZURE_TENANT_ID
      subscriptionId: $AZURE_SUBSCRIPTION_ID
      resourceGroupName: $AKS_GROUP
      metricName: kube_pod_status_ready
      metricFilter: namespace eq 'default'
      metricAggregationInterval: "0:1:0"
      metricAggregationType: Average
      targetValue: "1"
    authenticationRef:
      name: azure-monitor-trigger-auth
EOF
```


# builtin
cat <<EOF | kubectl apply -f -
apiVersion: autoscaling/v2beta2
kind: HorizontalPodAutoscaler
metadata:
  name: dummy-logger
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: dummy-logger
  minReplicas: 1
  maxReplicas: 10
  metrics:
  - type: Pods
    pods:
      metric:
        name: packets-per-second
      target:
        type: AverageValue
        averageValue: 10
EOF


cat <<EOF | kubectl apply -f -
apiVersion: autoscaling/v2beta2
kind: HorizontalPodAutoscaler
metadata:
  name: dummy-logger
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: dummy-logger
  minReplicas: 1
  maxReplicas: 10
  metrics:
  - type: Pods
    pods:
      metric:
        name: http_requests
      target:
        type: AverageValue
        averageValue: 10
EOF

###

kubectl create deployment hello-echo --image=k8s.gcr.io/echoserver:1.10 --namespace=ingress-basic

kubectl expose deployment echoserver --type=LoadBalancer --port=8080 --namespace=ingress-basic

cat <<EOF | kubectl apply -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: calculator-ingress
  namespace: ingress-basic
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt
spec:
  tls:
  - hosts:
    - 20.50.218.151.xip.io
    secretName: tls-secret
  rules:
  - host: 20.50.218.151.xip.io
    http:
      paths:
      - backend:
          serviceName: echoserver
          servicePort: 8080
        path: /
EOF
