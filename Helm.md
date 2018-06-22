# Using Helm

## Installing helm and tiller
https://github.com/kubernetes/helm
https://docs.microsoft.com/en-us/azure/aks/kubernetes-helm

Install helm
```
wget https://storage.googleapis.com/kubernetes-helm/helm-v2.7.2-linux-amd64.tar.gz
tar -zxvf helm-v2.7.2-linux-amd64.tar.gz
sudo mv linux-amd64/helm /usr/local/bin/helm
```

Install tiller and upgrade tiller
```
helm

helm init
echo "Upgrading tiller..."
helm init --upgrade
echo "Upgrading chart repo..."
helm repo update
```

If you are on 2.7.2 and want explicitly up/downgrade to 2.6.1:
```
export TILLER_TAG=v2.6.1
kubectl --namespace=kube-system set image deployments/tiller-deploy tiller=gcr.io/kubernetes-helm/tiller:$TILLER_TAG
```

See all pods (including tiller)
```
kubectl get pods --namespace kube-system
```

reinstall or delte tiller
```
kubectl delete deployment tiller-deploy -n kube-system
helm reset
```

```
helm install stable/mysql
https://kubeapps.com/
```

## Setting up helm for a dedicated namespace if you have RBAC

https://github.com/kubernetes/helm/blob/master/docs/rbac.md
```
APP_NAME=calculator-helm
kubectl create ns $APP_NAME
kubectl create serviceaccount tiller-$APP_NAME -n $APP_NAME

cat <<EOF | kubectl create -f -
kind: Role
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: $APP_NAME-manager
  namespace: $APP_NAME
rules:
- apiGroups: ["", "extensions", "apps"]
  resources: ["*"]
  verbs: ["*"]
EOF

cat <<EOF | kubectl create -f -
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: $APP_NAME-binding
  namespace: $APP_NAME
subjects:
- kind: ServiceAccount
  name: tiller-$APP_NAME
  namespace: $APP_NAME
roleRef:
  kind: Role
  name: $APP_NAME-manager
  apiGroup: rbac.authorization.k8s.io
EOF

helm init --service-account tiller-$APP_NAME --tiller-namespace $APP_NAME

helm install multicalchart --name=calculator --set frontendReplicaCount=3 --set backendReplicaCount=2 --set image.frontendTag=latest --set image.backendTag=latest --set useAppInsights=yes --tiller-namespace $APP_NAME --namespace $APP_NAME

```



## Create your own helm chart

1. Create using draft
Go to app folder and launch draft
https://github.com/Azure/draft 
```
draft create
```

2. Create helm chart manually and modify accordingly

```
helm create multicalc
```
Validate template
```
helm lint ./multicalchart
```

3. Dry run the chart and override parameters
```
helm install --dry-run --debug ./multicalchart --set frontendReplicaCount=3
```

4. Make sure you have the app insights key secret provisioned
```
kubectl create secret generic appinsightsecret --from-literal=appinsightskey=$APPINSIGHTS_KEY
```

5. Install
```
helm install multicalchart --name=calculator --set frontendReplicaCount=1 --set backendReplicaCount=1 --set image.frontendTag=latest --set image.backendTag=latest --set useAppInsights=yes
```

verify
```
helm get values calculator
```

6. Change config and perform an upgrade
```
helm upgrade --set backendReplicaCount=4 --set frontendReplicaCount=4 calculator multicalchart
```

If you have a redis secret you can turn on the redis cache
```
kubectl create secret generic rediscachesecret --from-literal=redishostkey=$REDIS_HOST --from-literal=redisauthkey=$REDIS_AUTH

helm upgrade --set backendReplicaCount=4 --set frontendReplicaCount=4 --set useAppInsights=yes --set useRedis=yes calculator multicalchart
```

7. See rollout history
```
helm history calculator
helm rollback calculator 1
```

6. Cleanup
```
helm delete calculator --purge
```
