# Create Demo

0. Variabeles
```
DEPL_NAME="hellodemo"
NS_NAME="helloworld"
```

1. Create namespace for demo
```
kubectl create ns $NS_NAME
```

2. Schedule deployment for nginx in ns
```
kubectl run $DEPL_NAME --image nginx -n $NS_NAME
```
Check pods
```
kubectl get pods --all-namespaces
kubectl get pods -o wide
```
3. Delete pod from namespace
```
kubectl delete pod $DEPL_NAME -n $NS_NAME
```