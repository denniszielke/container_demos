

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
```
## echo

```
kubectl run hello-world --quiet --image=busybox --restart=OnFailure -- echo "Hello Kubernetes!"

```

## crashing
```
kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/logging/crashing-app/crashing-app.yaml
```

## vm logger
```
curl -sL https://run.linkerd.io/install | sh



```

## linkerd smi
https://linkderdsmi.westeurope.cloudapp.azure.com/

https://aka.ms/ci-privatepreview

http://aka.ms/AMPMonitoring 
