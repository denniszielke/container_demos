# Using Helm

## Installing helm and tiller
https://github.com/kubernetes/helm
https://docs.microsoft.com/en-us/azure/aks/kubernetes-helm
https://chocolatey.org/packages/kubernetes-helm

https://github.com/core-process/aks-terraform-helm
https://github.com/dwaiba/aks-terraform

1. Install helm
```
wget https://storage.googleapis.com/kubernetes-helm/helm-v2.9.1-linux-amd64.tar.gz
tar -zxvf helm-v2.9.1-linux-amd64.tar.gz
sudo mv linux-amd64/helm /usr/local/bin/helm
```

upgrade helm via homebrew
```
brew upgrade kubernetes-helm
```

2. Install tiller and upgrade tiller
```
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

## Setting up helm via kube-system for the whole cluster with RBAC

```
kubectl create serviceaccount tiller --namespace kube-system
kubectl create clusterrolebinding tiller --clusterrole=cluster-admin --serviceaccount=kube-system:tiller --namespace kube-system
helm init --service-account tiller --upgrade
```

or via yaml

```
cat <<EOF | kubectl create -f -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: tiller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: tiller
    namespace: kube-system
EOF
```

init tiller with the new service account

```
helm init --service-account tiller --upgrade
helm version
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

Secure tiller:
https://github.com/michelleN/helm-secure-tiller 

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
APP_NS=calculator
APP_IN=calc1
```
Validate template
```
helm lint ./multicalchart
```

3. Dry run the chart and override parameters
```
helm install --dry-run --debug ./multicalchart --name=calculator --set frontendReplicaCount=3
```

4. Make sure you have the app insights key secret provisioned
```
kubectl create secret generic appinsightsecret --from-literal=appinsightskey=$APPINSIGHTS_KEY --namespace $APP_NS
```

5. Install
```
helm install multicalchart --name=$APP_IN --set frontendReplicaCount=3 --set backendReplicaCount=3 --set usePodRedis=no --namespace $APP_NS
```

verify
```
helm get values calculator
```

6. Change config and perform an upgrade
```
helm upgrade --set backendReplicaCount=3 --set frontendReplicaCount=3 $APP_IN multicalchart --namespace $APP_NS
helm upgrade --set backendReplicaCount=1 --set frontendReplicaCount=1 --set image.frontendTag=118 --set image.backendTag=120 --set dependencies.usePodRedis=yes $APP_IN multicalchart --namespace $APP_NS

```

If you have a redis secret you can turn on the redis cache
```
kubectl create secret generic rediscachesecret --from-literal=redishostkey=$REDIS_HOST --from-literal=redisauthkey=$REDIS_AUTH

helm upgrade --set backendReplicaCount=4 --set frontendReplicaCount=4 --set useAppInsights=yes --set useRedis=yes calculator $APP_IN --namespace $APP_NS
```

7. See rollout history
```
helm history $APP_IN
helm rollback $APP_IN 1
```

6. Cleanup
```
helm delete $APP_IN --purge
```
