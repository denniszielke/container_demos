# Using Helm

## Installing helm and tiller
https://github.com/kubernetes/helm
https://docs.microsoft.com/en-us/azure/aks/kubernetes-helm
https://chocolatey.org/packages/kubernetes-helm

https://github.com/core-process/aks-terraform-helm
https://github.com/dwaiba/aks-terraform

1. Install helm
```
wget https://storage.googleapis.com/kubernetes-helm/helm-v2.14.3-linux-amd64.tar.gz
tar -zxvf helm-v2.14.3-linux-amd64.tar.gz
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

kubectl delete secret appinsightsecret --namespace $APP_NS
```

5. Install
```
az configure --defaults acr=dzkubereg

az acr helm repo add

CHARTREPO=dzkubereg

helm install ./multicalchart --name=$APP_IN --set frontendReplicaCount=3 --set backendReplicaCount=3 --set dependencies.usePodRedis=false --set dependencies.useAppInsights=false --set image.repository=denniszielke --namespace $APP_NS --dry-run --debug

helm install $APP_IN ./multicalchart --set frontendReplicaCount=3 --set backendReplicaCount=3 --set dependencies.usePodRedis=false --set dependencies.useAppInsights=false --set image.repository=denniszielke  --set dependencies.useRedis=true --set dependencies.useAzureRedis=true --set dependencies.redisHostValue=$REDIS_HOST --set dependencies.redisKeyValue=$REDIS_AUTH --set introduceRandomResponseLag=true --set introduceRandomResponseLagValue=2  --namespace $APP_NS

helm upgrade $APP_IN ./multicalchart --set frontendReplicaCount=4 --set backendReplicaCount=4 --set dependencies.usePodRedis=false --set dependencies.useAppInsights=false --set image.repository=denniszielke  --set dependencies.useRedis=false --set dependencies.useAzureRedis=false --set dependencies.redisHostValue=$REDIS_HOST --set dependencies.redisKeyValue=$REDIS_AUTH --set introduceRandomResponseLag=true --set introduceRandomResponseLagValue=2  --namespace $APP_NS
```

verify
```
helm get values calculator
```

6. Change config and perform an upgrade
```
helm upgrade $APP_IN ./multicalchart --recreate-pods --set backendReplicaCount=1 --set frontendReplicaCount=1 --namespace $APP_NS

helm upgrade $APP_IN ./multicalchart --recreate-pods --set backendReplicaCount=3 --set frontendReplicaCount=4 --set introduceRandomResponseLag=true --set introduceRandomResponseLagValue=5 --namespace $APP_NS

helm upgrade $APP_IN ./multicalchart --set backendReplicaCount=3 --set frontendReplicaCount=3 --set image.repository=denniszielke --set image.backendImage=go-calc-backend --set dependencies.usePodRedis=true  --namespace $APP_NS 

helm upgrade $APP_IN ./multicalchart --set backendReplicaCount=1 --set frontendReplicaCount=1 --set image.repository=denniszielke --set image.backendImage=js-calc-backend --set dependencies.usePodRedis=false  --namespace $APP_NS 

helm upgrade $APP_IN ./multicalchart --set backendReplicaCount=3 --set frontendReplicaCount=3 --set image.repository=denniszielke --set dependencies.useAppInsights=true --set dependencies.appInsightsSecretValue=$APPINSIGHTS_KEY --set dependencies.usePodRedis=true  --namespace $APP_NS 
```

If you have a redis secret you can turn on the redis cache
```
REDIS_HOST=redis-master
REDIS_AUTH=secretpassword
APPINSIGHTS_KEY=

kubectl create secret generic rediscachesecret --from-literal=redishostkey=$REDIS_HOST --from-literal=redisauthkey=$REDIS_AUTH --namespace $APP_NS

helm upgrade $APP_IN ./multicalchart --set backendReplicaCount=3 --set frontendReplicaCount=3 --set image.repository=denniszielke --set dependencies.useAppInsights=true --set dependencies.appInsightsSecretValue=$APPINSIGHTS_KEY --set dependencies.useAzureRedis=false --set dependencies.usePodRedis=false --namespace $APP_NS


helm upgrade $APP_IN ./multicalchart --recreate-pods --set backendReplicaCount=4 --set frontendReplicaCount=5 --set image.repository=denniszielke --set image.frontendTag=latest --set image.backendTag=latest --set dependencies.useAppInsights=true --set dependencies.appInsightsSecretValue=$APPINSIGHTS_KEY --set dependencies.useRedis=true --set dependencies.useAzureRedis=true --set dependencies.redisHostValue=$REDIS_HOST --set dependencies.redisKeyValue=$REDIS_AUTH --set introduceRandomResponseLag=true --set introduceRandomResponseLagValue=2 --namespace $APP_NS

helm upgrade $APP_IN ./multicalchart --recreate-pods --set backendReplicaCount=1 --set frontendReplicaCount=1 --set image.repository=denniszielke --set image.frontendTag=latest --set image.backendTag=latest --set dependencies.useAppInsights=false --set dependencies.useAzureRedis=false --set dependencies.usePodRedis=true --set introduceRandomResponseLag=false --set introduceRandomResponseLagValue=0 --namespace $APP_NS

helm upgrade $APP_IN ./multicalchart --install --recreate-pods --set backendReplicaCount=3 --set frontendReplicaCount=3 --set image.repository=denniszielke --set image.frontendTag=latest --set image.backendTag=latest --set dependencies.useAppInsights=true --set dependencies.appInsightsSecretValue=$APPINSIGHTS_KEY --set dependencies.useAzureRedis=false --set dependencies.usePodRedis=true  --set introduceRandomResponseLag=false --set introduceRandomResponseLagValue=3 --namespace $APP_NS

helm upgrade $APP_IN ./multicalchart --install --recreate-pods --set backendReplicaCount=3 --set frontendReplicaCount=3 --set image.repository=denniszielke --set image.frontendTag=latest --set image.backendTag=latest --set dependencies.useAppInsights=true --set dependencies.appInsightsSecretValue=$APPINSIGHTS_KEY --set dependencies.useAzureRedis=true --set dependencies.redisHostValue=$REDIS_HOST --set dependencies.redisKeyValue=$REDIS_AUTH --set introduceRandomResponseLag=true --set introduceRandomResponseLagValue=3 --namespace $APP_NS

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

## Helm Template for Linkerd

```
APP_IN=calc1
APP_NS=calculator
export PATH=$PATH:$HOME/.linkerd2/bin 

helm template --name=$APP_IN --set frontendReplicaCount=1 --set backendReplicaCount=1 --set dependencies.usePodRedis=false --set dependencies.useAppInsights=true --set dependencies.appInsightsSecretValue=$APPINSIGHTS_KEY --set image.repository=denniszielke --output-dir ./manifests ./multicalchart

kubectl apply --recursive --filename ./manifests/multicalchart --namespace $APP_NS

kubectl get -n $APP_NS deploy -o yaml \
  | linkerd inject - \
  | kubectl apply -f -

export SERVICE_IP=$(kubectl get svc --namespace $APP_NS $APP_IN-calc-frontend-svc -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
open http://$SERVICE_IP:80

```

## Helm3

```
wget https://get.helm.sh/helm-v3.0.0-rc.3-darwin-amd64.tar.gz
tar -zxvf helm-v3.0.0-rc.3-darwin-amd64.tar.gz
alias helm3='/Users/dennis/lib/darwin-amd64/helm3'

HELM_REPOSITORY_CACHE="/Users/dennis/Library/Caches/helm3/repository"
HELM_REPOSITORY_CONFIG="/Users/dennis/Library/Preferences/helm3/repositories.yaml"
HELM_NAMESPACE="default"
HELM_KUBECONTEXT=""
HELM_BIN="/Users/dennis/lib/darwin-amd64/helm3"
HELM_DEBUG="false"
HELM_PLUGINS="/Users/dennis/Library/helm3/plugins"
HELM_REGISTRY_CONFIG="/Users/dennis/Library/Preferences/helm3/registry.json"
```

## Helm2 downgrade

https://medium.com/@yujunz/install-an-old-version-formula-from-homebrew-b2848f5ecc00


63cef9dba3efc5e5cb03dddd9eeae5ea52dee066

brew install https://github.com/Homebrew/homebrew-core/raw/63cef9dba3efc5e5cb03dddd9eeae5ea52dee066/Formula/kubernetes-helm.rb

helm repo add stable https://kubernetes-charts.storage.googleapis.com
