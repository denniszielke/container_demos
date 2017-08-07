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
docker build -t calc-backend .
eval "docker tag calc-backend $DOCKER_SERVER/calc-backend:v1"
eval "docker push $DOCKER_SERVER/calc-backend:v1"
docker run -p 8080:80 -e "INSTRUMENTATIONKEY=$INSTRUMENTATIONKEY" -e "PORT=80" calc-backend

cd kube_lab/multi-calculator/calc-frontend/
docker build -t calc-frontend .
eval "docker tag calc-frontend $DOCKER_SERVER/calc-frontend:v1"
eval "docker push $DOCKER_SERVER/calc-frontend:v1"
docker run -e "INSTRUMENTATIONKEY=$INSTRUMENTATIONKEY" -e"ENDPOINT=http://localhost:8080" -e "PORT=80" -p 8081:80 calc-frontend

```

4. Create a multi container deployment based of the multi-calculator/deploymultiaci.json
```
CONTAINER_NAME="multicalculator"
az group deployment create --name $CONTAINER_NAME --resource-group $RESOURCE_GROUP --template-file multi-calculator/deploymultiaci.json
```
or use  environment variables
```
az container create --name "$CONTAINER_NAME" --image microsoft/aci-helloworld --resource-group "$RESOURCE_GROUP" --ip-address public --environment-variables "INSTRUMENTATIONKEY=$INSTRUMENTATIONKEY"

```