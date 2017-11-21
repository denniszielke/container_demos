# Deploying and building multi calculator app

## Building and pushing images

0. Define variables

```
SUBSCRIPTION_ID=""
KUBE_GROUP=""
KUBE_NAME=""
LOCATION="northeurope"
REGISTRY_NAME=""
REGISTRY_PASSWORD=""
REGISTRY_URL="someregistry.azurecr.io"
APPINSIGHTS_KEY=
REDIS_HOST=
REDIS_AUTH=
```

1. Build images
```
docker build -t js-calc-frontend .
docker build -t js-calc-backend .
docker build -t go-calc-backend .
```

2. Tag Images
```
docker tag js-calc-frontend "$REGISTRY_URL/calc/js-calc-frontend"
docker tag js-calc-backend "$REGISTRY_URL/calc/js-calc-backend"
docker tag go-calc-backend "$REGISTRY_URL/calc/go-calc-backend"
```

3. Login
```
docker login --username $REGISTRY_NAME --password $REGISTRY_PASSWORD $REGISTRY_URL
```

4. Push images

```
docker push "$REGISTRY_URL/calc/js-calc-frontend"
docker push "$REGISTRY_URL/calc/js-calc-backend"
docker push "$REGISTRY_URL/calc/go-calc-backend"
```

or use the images from the docker hub

https://hub.docker.com/r/denniszielke/go-calc-backend/
https://hub.docker.com/r/denniszielke/js-calc-backend/
https://hub.docker.com/r/denniszielke/js-calc-frontend/

## Create Azure Container Registry secret in Kubernetes
https://medium.com/devoops-and-universe/your-very-own-private-docker-registry-for-kubernetes-cluster-on-azure-acr-ed6c9efdeb51

```
kubectl create secret docker-registry kuberegistry --docker-server 'myveryownregistry-on.azurecr.io' --docker-username 'username' --docker-password 'password' --docker-email 'example@example.com'

```

or

```
kubectl create secret docker-registry kuberegistry --docker-server $REGISTRY_URL --docker-username $REGISTRY_NAME --docker-password $REGISTRY_PASSWORD --docker-email 'example@example.com'
```

## Create Secrets for application insights and redis

0. Application insights key
```
kubectl create secret generic appinsightsecret --from-literal=appinsightskey=$APPINSIGHTS_KEY
```

1. Redis cache host and redis cache auth key
```
kubectl create secret generic rediscachesecret --from-literal=redishostkey=$REDIS_HOST --from-literal=redisauthkey=$REDIS_AUTH
```

## Perform app deployment

Use the full-acr-depl.yml file for deployment and modify it to your needs
```
kubectl apply -f 0-full-acr-depl.yml --record
```

Update the deployment and change from the js backend to the go backend
```
kubectl apply -f 1-full-acr-depl.yml --record
```

Watch the pods change one by one
```
kubectl get pods -l role=calcbackend
```

Check status
```
kubectl rollout status deployments calcbackend
```

Check the rollout history of a deployment
```
kubectl rollout history deployment/calcbackend
```

Rolling back to a specific revision rollout
```
kubectl rollout undo deployment/calcbackend --to-revision=2
```