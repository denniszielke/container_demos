# Multi container applications
https://docs.microsoft.com/en-us/azure/container-instances/container-instances-multi-container-group

1.  Login into azure cli
```
az login
```

2. Create a resource group
```
RESOURCE_GROUP="multihelloworld"
az group create --name "$RESOURCE_GROUP" --location westeurope
```

3. Build and push images to your registry
```
INSTRUMENTATIONKEY=""
git clone https://github.com/denniszielke/kube_lab.git
cd kube_lab/multi-calculator/calc-backend/
docker build -t calcbackend .
eval "docker tag calcbackend $DOCKER_SERVER/calcbackend:v1"
eval "docker push $DOCKER_SERVER/calcbackend:v1"
docker run -p 8080:80 -e "INSTRUMENTATIONKEY=$INSTRUMENTATIONKEY" -e "PORT=3001" calcbackend

cd kube_lab/multi-calculator/calc-frontend/
docker build -t calcfrontend .
eval "docker tag calcfrontend $DOCKER_SERVER/calcfrontend:v1"
eval "docker push $DOCKER_SERVER/calcfrontend:v1"
docker run -e "INSTRUMENTATIONKEY=$INSTRUMENTATIONKEY" -e"ENDPOINT=http://localhost:8080" -e "PORT=3000" -p 80:3000 calcfrontend

```

4. Create a multi container deployment based of the multi-calculator/deploymultiaci.json
```
CONTAINER_NAME="multicalculator"
az group deployment create --name $CONTAINER_NAME --resource-group $RESOURCE_GROUP --template-file multi-calculator/deploymultiaci.json
```
or use  environment variables
```
az container create --name "$CONTAINER_NAME" --image hellodemodz234.azurecr.io/calcbackend:v1 --resource-group "$RESOURCE_GROUP" --ip-address public --environment-variables INSTRUMENTATIONKEY=$INSTRUMENTATIONKEY PORT=80
az container logs --name "$CONTAINER_NAME" -g "$RESOURCE_GROUP"
az container show --name "$CONTAINER_NAME" -g "$RESOURCE_GROUP" --query ipAddress.ip

az container create --name "$CONTAINER_NAME" --image hellodemodz234.azurecr.io/calcfrontend:v1 --resource-group "$RESOURCE_GROUP" --ip-address public --environment-variables INSTRUMENTATIONKEY=$INSTRUMENTATIONKEY PORT=80 ENDPOINT=http://52.232.96.183

az container logs --name "$CONTAINER_NAME" -g "$RESOURCE_GROUP"
az container show --name "$CONTAINER_NAME" -g "$RESOURCE_GROUP" --query ipAddress.ip


```