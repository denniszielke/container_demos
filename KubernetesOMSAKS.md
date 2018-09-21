# Deploy the OMS (AKS)

https://docs.microsoft.com/en-us/azure/aks/tutorial-kubernetes-monitor

## Deploy the secrets

0. Define variables

```
WORKSPACE_ID=
WORKSPACE_KEY=
```

1. Deploy the secreit

```
kubectl create secret generic omsagent-secret --from-literal=WSID=$WORKSPACE_ID --from-literal=KEY=$WORKSPACE_KEY
```

2. Deploy the oms daemons

```
kubectl create -f https://raw.githubusercontent.com/denniszielke/container_demos/master/logging/omsdaemonset.yaml
kubectl get daemonset
```

3. Create host to log from
```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: dummy-logger
  labels:
    app: dummy-logger
spec:
  containers:
    - name: dummy-logger
      image: denniszielke/dummy-logger:latest
      ports:
        - containerPort: 80
          name: http
          protocol: TCP
      resources:
        requests:
          memory: "128Mi"
          cpu: "500m"
        limits:
          memory: "256Mi"
          cpu: "1000m"
---
apiVersion: v1
kind: Service
metadata:
  name: dummy-logger
  namespace: default
spec:
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: dummy-logger
  type: LoadBalancer
EOF
```

4. Log something
```
curl 

kubectl get svc dummy-logger -o template --template "{{(index .items 0).status.loadBalancer.ingress }}"
```

5. Evaluate the logs by referencing the docs
https://docs.microsoft.com/en-us/azure/log-analytics/log-analytics-containers 

6. Cleanup
```
kubectl delete -f https://raw.githubusercontent.com/denniszielke/container_demos/master/logging/ubuntuhost.yml
kubectl delete -f https://raw.githubusercontent.com/denniszielke/container_demos/master/logging/omsdaemonset.yaml
kubectl delete secret omsagent-secret
```
