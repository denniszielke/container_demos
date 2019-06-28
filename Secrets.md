# Deploy Secrets
https://kubernetes.io/docs/concepts/configuration/secret/

1. The app needs application insights configured inside the cluster under the name appinsightsecret
```
kubectl create secret generic appinsightsecret --from-literal=appinsightskey=$APPINSIGHTS_KEY
```

or 

Secrets must be base64 encoded  & then deployed secret to cluster
```
echo -n "1f2d1e2e67df" | base64
kubectl create -f appinsightsecret.yml
```

2. The secret for accessing your container registry

```
kubectl create secret docker-registry kuberegistry --docker-server 'myveryownregistry-on.azurecr.io' --docker-username 'username' --docker-password 'password' --docker-email 'example@example.com'
```

or

```
kubectl create secret docker-registry kuberegistry --docker-server $REGISTRY_URL --docker-username $REGISTRY_NAME --docker-password $REGISTRY_PASSWORD --docker-email 'example@example.com'
```
