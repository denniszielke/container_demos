

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


curl -X POST http://$DUMMY_LOGGER_IP/api/log -H "message: {more: content}" 
curl -X POST http://$DUMMY_LOGGER_IP/api/log -H "message: hi" 

```
## echo

```
kubectl run hello-world --quiet --image=busybox --restart=OnFailure -- echo "Hello Kubernetes!"

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


## calc
```
AZURE_CONTAINER_REGISTRY_NAME=charts
KUBERNETES_NAMESPACE=calculator
BUILD_BUILDNUMBER=latest
AZURE_CONTAINER_REGISTRY_URL=denniszielke

kubectl create namespace $KUBERNETES_NAMESPACE

osm namespace add calculator --mesh-name osm --enable-sidecar-injection 

helm upgrade calculator $AZURE_CONTAINER_REGISTRY_NAME/multicalculator --namespace $KUBERNETES_NAMESPACE --install --set replicaCount=4 --set image.frontendTag=$BUILD_BUILDNUMBER --set image.backendTag=$BUILD_BUILDNUMBER --set image.repository=$AZURE_CONTAINER_REGISTRY_URL --set dependencies.usePodRedis=true --set ingress.enabled=false --set service.type=LoadBalancer --set noProbes=true --wait --timeout 45s

helm delete calculator -n $KUBERNETES_NAMESPACE
```
## crashing
```
kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/logging/crashing-app/crashing-app.yaml

export CRASHING_APP_IP=$(kubectl get svc --namespace $DEMO_NS crashing-app -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

curl -X GET http://$CRASHING_APP_IP/crash

```

## vm logger
```
curl -sL https://run.linkerd.io/install | sh



```

## linkerd smi
https://linkderdsmi.westeurope.cloudapp.azure.com/

https://aka.ms/ci-privatepreview

http://aka.ms/AMPMonitoring 
