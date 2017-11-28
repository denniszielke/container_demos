# Deploy the OMS (AKS)

https://docs.microsoft.com/en-us/azure/aks/tutorial-kubernetes-monitor

## Deploy the secrets

0. Define variables

```
OMS_WS_ID=
OMS_WS_KEY=
```

1. Deploy the secreit

```
kubectl create secret generic omsecret --from-literal=omsid=$OMS_WS_ID --from-literal=omskey=$OMS_WS_KEY
```

2. Deploy the oms daemons

```
kubectl create -f omsdaemonset.yaml
kubectl get daemonset
```

3. Create host to log from
```
kubectl create -f ubuntuhost.yaml
```

4. Log something
```
kubectl exec -ti ubuntuhost -- logger something
```

5. Cleanup
```
kubectl delete -f ubuntuhost.yaml
kubectl delete -f omsdaemonset.yaml
```