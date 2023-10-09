

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

kubectl patch svc azure-vote-front -p '{"metadata": {"annotations":{"service.beta.kubernetes.io/azure-load-balancer-internal":"true"}} }'


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
  namespace: calculator
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

## nginx

```

helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace

```

## calc
```

helm repo add phoenix 'https://raw.githubusercontent.com/denniszielke/phoenix/master/'
helm repo update
helm search repo phoenix 

AZURE_CONTAINER_REGISTRY_NAME=phoenix
KUBERNETES_NAMESPACE=calculator
BUILD_BUILDNUMBER=latest
AZURE_CONTAINER_REGISTRY_URL=denniszielke
APPINSIGHTY_KEY=InstrumentationKey=
AZURE_REDIS_HOST=.redis.cache.windows.net
AZURE_REDIS_KEY=
DNS=ndzcilium3.northeurope.cloudapp.azure.com

kubectl create namespace $KUBERNETES_NAMESPACE

kubectl label namespace $KUBERNETES_NAMESPACE istio.io/rev=asm-1-17

echo "without anything"
helm upgrade calculator $AZURE_CONTAINER_REGISTRY_NAME/multicalculator --namespace $KUBERNETES_NAMESPACE --install --create-namespace --set replicaCount=2 --set image.frontendTag=$BUILD_BUILDNUMBER --set image.backendTag=$BUILD_BUILDNUMBER --set image.repository=$AZURE_CONTAINER_REGISTRY_URL --set dependencies.usePodRedis=false --set ingress.enabled=false --set service.type=LoadBalancer --set ingress.tls=false  --set introduceRandomResponseLag=true --set introduceRandomResponseLagValue=2 --set dependencies.useAppInsights=false --set dependencies.useAzureRedis=false --wait 

echo "without AI but with Redis"
helm upgrade calculator $AZURE_CONTAINER_REGISTRY_NAME/multicalculator --namespace $KUBERNETES_NAMESPACE --install --create-namespace --set replicaCount=2 --set image.frontendTag=$BUILD_BUILDNUMBER --set image.backendTag=$BUILD_BUILDNUMBER --set image.repository=$AZURE_CONTAINER_REGISTRY_URL --set dependencies.usePodRedis=false --set ingress.enabled=false --set service.type=LoadBalancer --set ingress.tls=false  --set introduceRandomResponseLag=false --set introduceRandomResponseLagValue=1 --set dependencies.useAppInsights=false --set dependencies.useAzureRedis=true --set dependencies.redisHostValue=$AZURE_REDIS_HOST --set dependencies.redisKeyValue=$AZURE_REDIS_KEY --wait 


helm upgrade calculator $AZURE_CONTAINER_REGISTRY_NAME/multicalculator --namespace $KUBERNETES_NAMESPACE --install --create-namespace --set replicaCount=4 --set image.frontendTag=$BUILD_BUILDNUMBER --set image.backendTag=$BUILD_BUILDNUMBER --set image.repository=$AZURE_CONTAINER_REGISTRY_URL --set dependencies.usePodRedis=true --set ingress.enabled=true --set ingress.tls=true --set ingress.host=$DNS  --set noProbes=true --set introduceRandomResponseLag=true --set introduceRandomResponseLagValue=2 --set dependencies.useAppInsights=true --set dependencies.appInsightsSecretValue=$APPINSIGHTY_KEY --wait --timeout 45s

helm upgrade calculator $AZURE_CONTAINER_REGISTRY_NAME/multicalculator --namespace $KUBERNETES_NAMESPACE --install --create-namespace --set replicaCount=4 --set image.frontendTag=$BUILD_BUILDNUMBER --set image.backendTag=$BUILD_BUILDNUMBER --set image.repository=$AZURE_CONTAINER_REGISTRY_URL --set dependencies.usePodRedis=false --set dependencies.useAppInsights=true --set dependencies.appInsightsSecretValue=$APPINSIGHTY_KEY --set ingress.enabled=false --set service.type=LoadBalancer --set noProbes=true --set introduceRandomResponseLag=true --set introduceRandomResponseLagValue=2 --wait --timeout 45s

helm upgrade calculator $AZURE_CONTAINER_REGISTRY_NAME/multicalculator --namespace $KUBERNETES_NAMESPACE --install --create-namespace --set replicaCount=1 --set image.frontendTag=$BUILD_BUILDNUMBER --set image.backendTag=$BUILD_BUILDNUMBER --set image.repository=$AZURE_CONTAINER_REGISTRY_URL --set dependencies.usePodRedis=true --set dependencies.useAppInsights=true --set dependencies.appInsightsSecretValue=$APPINSIGHTY_KEY --set ingress.enabled=false --set service.type=LoadBalancer --set noProbes=true --set introduceRandomResponseLag=true --set introduceRandomResponseLagValue=2 --set dependencies.useAzureRedis=true --set dependencies.redisHostValue=$AZURE_REDIS_HOST --set dependencies.redisKeyValue=$AZURE_REDIS_KEY --set dependencies.usePodRedis=false --wait --timeout 45s

helm upgrade calculator $AZURE_CONTAINER_REGISTRY_NAME/multicalculator --namespace $KUBERNETES_NAMESPACE --install --create-namespace --set replicaCount=4 --set image.frontendTag=$BUILD_BUILDNUMBER --set image.backendTag=$BUILD_BUILDNUMBER --set image.repository=$AZURE_CONTAINER_REGISTRY_URL --set dependencies.useAzureRedis=true --set dependencies.redisHostValue=$AZURE_REDIS_HOST --set dependencies.redisKeyValue=$AZURE_REDIS_KEY --set dependencies.useAppInsights=true --set dependencies.appInsightsSecretValue=$APPINSIGHTY_KEY --set dependencies.useIngress=true --set ingress.enabled=true --set ingress.host=$DNS --set service.type=ClusterIP --set noProbes=true --set introduceRandomResponseLag=true --set introduceRandomResponseLagValue=3 --wait --timeout 45s

helm upgrade calculator $AZURE_CONTAINER_REGISTRY_NAME/multicalculator --namespace $KUBERNETES_NAMESPACE --install --create-namespace --set replicaCount=1 --set image.frontendTag=$BUILD_BUILDNUMBER --set image.backendTag=$BUILD_BUILDNUMBER --set image.repository=$AZURE_CONTAINER_REGISTRY_URL --set dependencies.useAzureRedis=true --set dependencies.redisHostValue=$AZURE_REDIS_HOST --set dependencies.redisKeyValue=$AZURE_REDIS_KEY --set dependencies.useAppInsights=true --set dependencies.appInsightsSecretValue=$APPINSIGHTY_KEY --set dependencies.useIngress=true --set ingress.enabled=true --set ingress.tls=false --set ingress.host=$DNS --set service.type=ClusterIP --set noProbes=false --set introduceRandomResponseLag=true --set introduceRandomResponseLagValue=3 --set deployRequester=true --wait --timeout 45s

helm delete calculator -n $KUBERNETES_NAMESPACE

kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: calculator-gateway-external
  namespace: $KUBERNETES_NAMESPACE
spec:
  selector:
    istio: aks-istio-ingressgateway-external
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*"
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: calculator-vs-external
  namespace: $KUBERNETES_NAMESPACE
spec:
  hosts:
  - "*"
  gateways:
  - calculator-gateway-external
  http:
  - match:
    - uri:
        prefix: /
    route:
    - destination:
        host: calculator-multicalculator-frontend-svc
        port:
          number: 8080
EOF

```
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: allowed
spec:
  endpointSelector: {}
  ingress:
    - fromEntities:
        - cluster
  egress:
    - toFQDNs:
        - matchPattern: "*.in.applicationinsights.azure.com"
      toPorts:
        - ports:
            - port: "443"
    - toFQDNs:
        - matchPattern: "*.livediagnostics.monitor.azure.com"
      toPorts:
        - ports:
            - port: "443"
    - toFQDNs:
        - matchName: dzcache.redis.cache.windows.net
      toPorts:
        - ports:
            - port: "443"

kubectl apply -f - <<EOF
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: backend-policy
  namespace: calculator
spec:
  podSelector:
    matchLabels:
      role: backend
  ingress:
  - from:
    - podSelector:
        matchLabels:
          role: frontend
EOF

```



```
## Health model

```
AppRequests
| where TimeGenerated < ago(10m)
| where Success == true
| where AppRoleName == "calculator-multicalculator-frontend.calculator"
| summarize avg(DurationMs)

AppRequests
| where TimeGenerated < ago(10m)
| where Success == true
| where AppRoleName == "calculator-multicalculator-backend.calculator"
| summarize avg(DurationMs)

requests
| where timestamp < ago(10m)
| where cloud_RoleName == "calculator-multicalculator-backend.calculator"
| summarize avg(duration)

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

export OPENAI_API_KEY=
export OPENAI_API_BASE=
export OPENAI_API_DEPLOYMENT=gpt4
export OPENAI_API_TYPE=azure