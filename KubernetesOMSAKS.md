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
kubectl create -f https://raw.githubusercontent.com/denniszielke/container_demos/master/oms/omsdaemonset.yaml
kubectl get daemonset
```

3. Create host to log from
```
kubectl create -f https://raw.githubusercontent.com/denniszielke/container_demos/master/oms/ubuntuhost.yml
```

4. Log something
```
kubectl exec -ti ubuntuhost -- logger something
```

5. Evaluate the logs by referencing the docs
https://docs.microsoft.com/en-us/azure/log-analytics/log-analytics-containers 

6. Cleanup
```
kubectl delete -f https://raw.githubusercontent.com/denniszielke/container_demos/master/oms/ubuntuhost.yml
kubectl delete -f https://raw.githubusercontent.com/denniszielke/container_demos/master/oms/omsdaemonset.yaml
```
