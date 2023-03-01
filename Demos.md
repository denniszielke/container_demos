

## logging

```
kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/logging/dummy-logger/pod-logger.yaml
kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/logging/dummy-logger/depl-logger.yaml
kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/logging/dummy-logger/svc-lb-logger.yaml
kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/logging/dummy-logger/svc-cluster-logger.yaml
kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/logging/dummy-logger/svc-int-logger.yaml
kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/logging/dummy-logger/svc-lb-logger.yaml
kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/logging/dummy-logger/svc-lb-pl-logger.yaml
kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/logging/dummy-logger/svc-node-logger.yaml


export DUMMY_LOGGER_IP=$(kubectl get svc --namespace $DEMO_NS dummy-logger-svc-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
export DUMMY_LOGGER_IP=$(kubectl get svc dummy-logger-pub-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

kubectl patch deployment simple --type=json -p='[{"op": "add", "path": "/spec/template/metadata/labels/this", "value": "that"}]'

kubectl patch svc dummy-logger-pub-lb  --type='json' -p='[{"op": "add", "path": "/metadata/annotations/service.beta.kubernetes.io/azure-load-balancer-internal", "value":"true"}]'

kubectl patch svc dummy-logger-pub-lb -p '{"metadata": {"annotations":{"service.beta.kubernetes.io/azure-load-balancer-internal":"true"}} }'


curl -X POST http://$DUMMY_LOGGER_IP/api/log -H "message: {more: content}" 
curl -X POST http://$DUMMY_LOGGER_IP/api/log -H "message: hi" 

cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  name: dummy-ingress
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
  - host: $DNS
    http:
      paths:
      - path: /
        backend:
          serviceName: dummy-logger-int-lb
          servicePort: 80
EOF

```
## echo

```
kubectl run hello-world --quiet --image=busybox --restart=OnFailure -- echo "Hello Kubernetes!"

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: centos
spec:
  containers:
  - name: centos
    image: centos
    ports:
    - containerPort: 80
    command:
    - sleep
    - "3600"
EOF

```

## emojivoto
```
kubectl create namespace emojivoto
osm namespace add emojivoto --mesh-name osm

curl -sL https://run.linkerd.io/emojivoto.yml \
  | kubectl apply -f -

kubectl -n emojivoto port-forward svc/web-svc 8080:80
```

## dummy
```
kubectl create namespace dummy
osm namespace add dummy --mesh-name osm
kubectl run --generator=run-pod/v1 --image=dummy-logger dummy-logger --port=80 -n aadsecured

kubectl port-forward -n osm-simple-app frontend-7794dbcdc7-rdmjz 8080:80

```

## crashing app
```
kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/logging/crashing-app/crashing-depl.yaml
kubectl scale deployment crashing-app -n crashing-app --replicas=4


```

## calc
```
AZURE_CONTAINER_REGISTRY_NAME=charts
KUBERNETES_NAMESPACE=calculator
BUILD_BUILDNUMBER=latest
AZURE_CONTAINER_REGISTRY_URL=denniszielke
APPINSIGHTY_KEY=
AZURE_REDIS_HOST=.redis.cache.windows.net
AZURE_REDIS_KEY=
DNS=.uksouth.cloudapp.azure.com

kubectl create namespace $KUBERNETES_NAMESPACE

osm namespace add calculator --mesh-name osm --enable-sidecar-injection 

helm upgrade calculator $AZURE_CONTAINER_REGISTRY_NAME/multicalculator --namespace $KUBERNETES_NAMESPACE --install --set replicaCount=4 --set image.frontendTag=$BUILD_BUILDNUMBER --set image.backendTag=$BUILD_BUILDNUMBER --set image.repository=$AZURE_CONTAINER_REGISTRY_URL --set dependencies.usePodRedis=true --set ingress.enabled=true --set ingress.tls=true --set ingress.host=$DNS  --set noProbes=true --set introduceRandomResponseLag=true --set introduceRandomResponseLagValue=2 --wait --timeout 45s

helm upgrade calculator $AZURE_CONTAINER_REGISTRY_NAME/multicalculator --namespace $KUBERNETES_NAMESPACE --install --set replicaCount=4 --set image.frontendTag=$BUILD_BUILDNUMBER --set image.backendTag=$BUILD_BUILDNUMBER --set image.repository=$AZURE_CONTAINER_REGISTRY_URL --set dependencies.usePodRedis=true --set ingress.enabled=true --set ingress.tls=true --set ingress.host=$DNS  --set noProbes=true --set introduceRandomResponseLag=true --set introduceRandomResponseLagValue=2 --set dependencies.useAppInsights=true --set dependencies.appInsightsSecretValue=$APPINSIGHTY_KEY --wait --timeout 45s

helm upgrade calculator $AZURE_CONTAINER_REGISTRY_NAME/multicalculator --namespace $KUBERNETES_NAMESPACE --install --set replicaCount=4 --set image.frontendTag=$BUILD_BUILDNUMBER --set image.backendTag=$BUILD_BUILDNUMBER --set image.repository=$AZURE_CONTAINER_REGISTRY_URL --set dependencies.usePodRedis=true --set ingress.enabled=true --set ingress.tls=true --set ingress.host=$DNS  --set noProbes=true --set introduceRandomResponseLag=true --set introduceRandomResponseLagValue=2 --set dependencies.useAppInsights=true --set dependencies.appInsightsSecretValue=$APPINSIGHTY_KEY --set dependencies.useAzureRedis=true --set dependencies.redisHostValue=$AZURE_REDIS_HOST --set dependencies.redisKeyValue=$AZURE_REDIS_KEY --set dependencies.usePodRedis=false  --wait --timeout 45s

helm upgrade calculator $AZURE_CONTAINER_REGISTRY_NAME/multicalculator --namespace $KUBERNETES_NAMESPACE --install --set replicaCount=4 --set image.frontendTag=$BUILD_BUILDNUMBER --set image.backendTag=$BUILD_BUILDNUMBER --set image.repository=$AZURE_CONTAINER_REGISTRY_URL --set dependencies.usePodRedis=true --set dependencies.useAppInsights=true --set dependencies.appInsightsSecretValue=$APPINSIGHTY_KEY --set ingress.enabled=false --set service.type=LoadBalancer --set noProbes=true --set introduceRandomResponseLag=true --set introduceRandomResponseLagValue=2 --wait --timeout 45s

helm upgrade calculator $AZURE_CONTAINER_REGISTRY_NAME/multicalculator --namespace $KUBERNETES_NAMESPACE --install --set replicaCount=1 --set image.frontendTag=$BUILD_BUILDNUMBER --set image.backendTag=$BUILD_BUILDNUMBER --set image.repository=$AZURE_CONTAINER_REGISTRY_URL --set dependencies.usePodRedis=true --set dependencies.useAppInsights=true --set dependencies.appInsightsSecretValue=$APPINSIGHTY_KEY --set ingress.enabled=false --set service.type=LoadBalancer --set noProbes=true --set introduceRandomResponseLag=true --set introduceRandomResponseLagValue=2 --set dependencies.useAzureRedis=true --set dependencies.redisHostValue=$AZURE_REDIS_HOST --set dependencies.redisKeyValue=$AZURE_REDIS_KEY --set dependencies.usePodRedis=false --wait --timeout 45s

helm upgrade calculator $AZURE_CONTAINER_REGISTRY_NAME/multicalculator --namespace $KUBERNETES_NAMESPACE --install --set replicaCount=4 --set image.frontendTag=$BUILD_BUILDNUMBER --set image.backendTag=$BUILD_BUILDNUMBER --set image.repository=$AZURE_CONTAINER_REGISTRY_URL --set dependencies.useAzureRedis=true --set dependencies.redisHostValue=$AZURE_REDIS_HOST --set dependencies.redisKeyValue=$AZURE_REDIS_KEY --set dependencies.useAppInsights=true --set dependencies.appInsightsSecretValue=$APPINSIGHTY_KEY --set dependencies.useIngress=true --set ingress.enabled=true --set ingress.host=$DNS --set service.type=ClusterIP --set noProbes=true --set introduceRandomResponseLag=true --set introduceRandomResponseLagValue=3 --wait --timeout 45s

helm upgrade calculator $AZURE_CONTAINER_REGISTRY_NAME/multicalculator --namespace $KUBERNETES_NAMESPACE --install --set replicaCount=1 --set image.frontendTag=$BUILD_BUILDNUMBER --set image.backendTag=$BUILD_BUILDNUMBER --set image.repository=$AZURE_CONTAINER_REGISTRY_URL --set dependencies.useAzureRedis=true --set dependencies.redisHostValue=$AZURE_REDIS_HOST --set dependencies.redisKeyValue=$AZURE_REDIS_KEY --set dependencies.useAppInsights=true --set dependencies.appInsightsSecretValue=$APPINSIGHTY_KEY --set dependencies.useIngress=true --set ingress.enabled=true --set ingress.tls=false --set ingress.host=$DNS --set service.type=ClusterIP --set noProbes=false --set introduceRandomResponseLag=true --set introduceRandomResponseLagValue=3 --set deployRequester=true --wait --timeout 45s

helm delete calculator -n $KUBERNETES_NAMESPACE
```
## crashing
```
kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/logging/crashing-app/crashing-app.yaml

export CRASHING_APP_IP=$(kubectl get svc --namespace $DEMO_NS crashing-app -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

curl -X GET http://$CRASHING_APP_IP/crash

```

## color

kubectl create namespace colors
osm namespace add colors
kubectl apply -f https://raw.githubusercontent.com/DanielMeixner/DebugContainer/master/yamls/red-green-yellow.yaml -n colors

kubectl port-forward -n colors deploy/appa 8009:80

## vm logger
```
curl -sL https://run.linkerd.io/install | sh
```
## dapr
```
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

helm upgrade redis bitnami/redis --install --set cluster.enabled=false --set password=secretpassword --namespace default
helm delete redis

cat <<EOF | kubectl apply -f -
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: statestore
spec:
  type: state.redis
  version: v1
  metadata:
  - name: redisHost
    value: redis-master:6379
  - name: redisPassword
    value: secretpassword
EOF

kubectl apply -f https://raw.githubusercontent.com/dapr/quickstarts/master/distributed-calculator/deploy/dotnet-subtractor.yaml
kubectl apply -f https://raw.githubusercontent.com/dapr/quickstarts/master/distributed-calculator/deploy/go-adder.yaml
kubectl apply -f https://raw.githubusercontent.com/dapr/quickstarts/master/distributed-calculator/deploy/node-divider.yaml
kubectl apply -f https://raw.githubusercontent.com/dapr/quickstarts/master/distributed-calculator/deploy/python-multiplier.yaml
kubectl apply -f https://raw.githubusercontent.com/dapr/quickstarts/master/distributed-calculator/deploy/react-calculator.yaml

kubectl apply -f https://raw.githubusercontent.com/dapr/quickstarts/master/distributed-calculator/deploy/redis.yaml
```
## linkerd smi
https://linkderdsmi.westeurope.cloudapp.azure.com/

https://aka.ms/ci-privatepreview

http://aka.ms/AMPMonitoring 

https://aka.ms/smartinsights

