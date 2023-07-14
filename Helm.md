# Using Helm

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

kubectl create namespace $APP_NS
```
Validate template
```
helm lint ./multicalchart
```

3. Dry run the chart and override parameters
```
helm install --dry-run --debug ./multicalculatorv3 --name=calculator --set frontendReplicaCount=3
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

helm upgrade $APP_IN ./multicalculatorv3 --namespace $APP_NS --install

helm upgrade $APP_IN ./multicalculatorv3 --namespace $APP_NS --install  --set replicaCount=1

helm upgrade $APP_IN ./multicalculatorv3 --namespace $APP_NS --install  --set replicaCount=4  --set dependencies.useAppInsights=true --set dependencies.appInsightsSecretValue=$APPINSIGHTS_KEY --set dependencies.usePodRedis=true
```

verify
```
helm list -n $APP_NS
helm get values $APP_IN $APP_IN
```

6. Change config and perform an upgrade
```
az monitor app-insights component create --app calc$KUBE_NAME --location $LOCATION --kind web -g $KUBE_GROUP --application-type web


APPINSIGHTS_KEY=
helm upgrade $APP_IN ./multicalculatorv3 --namespace $APP_NS --install  --set replicaCount=4  --set dependencies.useAppInsights=true --set dependencies.appInsightsSecretValue=$APPINSIGHTS_KEY --set dependencies.usePodRedis=true
```

If you have a redis secret you can turn on the redis cache
```
REDIS_HOST=.redis.cache.windows.net
REDIS_AUTH=
APPINSIGHTS_KEY=

kubectl create secret generic rediscachesecret --from-literal=redishostkey=$REDIS_HOST --from-literal=redisauthkey=$REDIS_AUTH --namespace $APP_NS

helm upgrade $APP_IN ./multicalculatorv3 --namespace $APP_NS --install  --set replicaCount=4  --set dependencies.useAppInsights=true --set dependencies.appInsightsSecretValue=$APPINSIGHTS_KEY --set dependencies.usePodRedis=true
--set dependencies.useAzureRedis=true --set dependencies.redisHostValue=$REDIS_HOST --set dependencies.redisKeyValue=$REDIS_AUTH

helm upgrade $APP_IN multicalculatorv3 --install --set backendReplicaCount=3 --set frontendReplicaCount=3 --set dependencies.useAppInsights=true --set dependencies.appInsightsSecretValue=$APPINSIGHTS_KEY --set dependencies.useAzureRedis=true --set dependencies.redisHostValue=$REDIS_HOST --set dependencies.redisKeyValue=$REDIS_AUTH --set introduceRandomResponseLag=false --set introduceRandomResponseLagValue=0 --namespace $APP_NS

helm upgrade $APP_IN multicalculatorv3 --install --set backendReplicaCount=3 --set frontendReplicaCount=3 --set dependencies.useAppInsights=true --set dependencies.appInsightsSecretValue=$APPINSIGHTS_KEY --set dependencies.useAzureRedis=true --set dependencies.redisHostValue=$REDIS_HOST --set dependencies.redisKeyValue=$REDIS_AUTH --set introduceRandomResponseLag=true --set introduceRandomResponseLagValue=3 --namespace $APP_NS --dry-run --debug
```

Configure scaler
```
kubectl autoscale deployment calc2-multicalculatorv3-backend -n calculator --cpu-percent=20 --min=1 --max=5

kubectl get hpa -n calculator

kubectl delete hpa calc1-multicalculatorv3-backend -n calculator

kubectl scale deployment calc1-multicalculatorv3-backend --replicas=1 -n calculator
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

## Helm repo in GitHub

```
cd phoenix
helm package ./charts/multicalculator  #This will create tgz file with chart in current directory
helm repo index . #This will create index.yaml file which references my-app-chart.yaml
git add .
git commit -m "my-app-chart"
git push
```


```
helm repo add phoenix 'https://raw.githubusercontent.com/denniszielke/phoenix/master/'
helm repo update
helm repo list
NAME URL
stable https://kubernetes-charts.storage.googleapis.com
local http://127.0.0.1:8879/charts
my-github-helmrepo https://raw.githubusercontent.com/my_organization/my-github-helm-repo/master/
helm search repo phoenix
NAME CHART VERSION APP VERSION DESCRIPTION
my-github-helmrepo/my-app-chart 0.1.0 1.0 A Helm chart for Kubernetes
```