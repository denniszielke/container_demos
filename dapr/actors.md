# DAPR - Actors

https://github.com/dapr/dotnet-sdk/blob/master/docs/get-started-dapr-actor.md
dotnet new sln -o dapr-actors

dotnet new classlib -o MyActor.Interfaces
cd MyActor.Interfaces

dotnet add package Dapr.Actors

# Setup remote state store
https://github.com/dapr/docs/tree/master/howto/setup-state-store

helm upgrade redis stable/redis --install --set password=secretpassword --set image.tag=5.0.5-debian-9-r104
helm upgrade redis stable/redis --install --set password=secretpassword --set cluster.enabled=false --namespace=redis

REDIS_HOST=redis-master:6379
REDIS_PASSWORD=secretpassword

REDIS_HOST=dzactors.redis.cache.windows.net:6379
REDIS_PASSWORD=


az k8s-extension create --cluster-type managedClusters \
--cluster-name $KUBE_NAME \
--resource-group $KUBE_GROUP \
--name dapr \
--extension-type Microsoft.Dapr \
--auto-upgrade-minor-version false


https://github.com/dapr/dapr/blob/master/docs/decision_records/api/API-008-multi-state-store-api-design.md

cat <<EOF | kubectl apply -f -
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: statestore
spec:
  type: state.redis
  metadata:
  - name: redisHost
    value: "$REDIS_HOST"
  - name: redisPassword
    value: "$REDIS_PASSWORD"
  - name: actorStateStore
    value: "true"
EOF


az cosmosdb collection create --collection-name actors --db-name dzactors --partition-key-path '/id' --resource-group $KUBE_GROUP --name $COSMOSDB_NAME
az cosmosdb keys list --resource-group $KUBE_GROUP --name $COSMOSDB_NAME

COSMOSDB_NAME=dzactors
KUBE_GROUP=kub_ter_a_l_dapr2

MASTER_KEY=

cat <<EOF | kubectl apply -f -
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: cosmosdb
spec:
  type: state.azure.cosmosdb
  metadata:
  - name: url
    value: https://$COSMOSDB_NAME.documents.azure.com:443/
  - name: masterKey
    value: $MASTER_KEY
  - name: database
    value: dzactors
  - name: collection
    value: actors
EOF

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: centos
  annotations:
    dapr.io/enabled: "true"
    dapr.io/id: "curlactor"
    dapr.io/port: "80"
    dapr.io/log-level: "debug"
spec:
  containers:
  - name: centoss
    image: centos
    ports:
    - containerPort: 3500
    command:
    - sleep
    - "3600"
EOF

kubectl exec -it centos -- /bin/bash
kubectl delete pod centos

curl -X GET http://127.0.0.1:3500/dapr/config -H "Content-Type: application/json"
curl -X GET http://dapr-api.default.svc.cluster.local:3500/dapr/config -H "Content-Type: application/json"

https://github.com/dapr/dapr-docs/blob/master/howto/query-state-store/query-redis-store.md


curl -X POST http://127.0.0.1:3005/v1.0/actors/DemoActor/abc/method/GetData

curl -X POST http://127.0.0.1:3005/v1.0/actors/DemoActor/abc1 -H "Content-Type: application/json"

curl -X POST http://127.0.0.1:3005/v1.0/actors/DemoActor/abc1/method/SaveData -d '{ "PropertyA": "ValueA", "PropertyB": "ValueB" }'

curl -X POST http://127.0.0.1:3005/v1.0/actors/DemoActor/abc/method/GetData