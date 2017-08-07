## Run a hello world container in Azure Container instances
See https://docs.microsoft.com/en-us/azure/container-instances/container-instances-quickstart

1.  Login into azure cli
`
az login
`

2. Create a resource group
`
RESOURCE_GROUP="helloworld"
az group create --name "$RESOURCE_GROUP" --location westeurope
`

3. Create a container instance
`
CONTAINER_NAME="acihelloworld"
az container create --name "$CONTAINER_NAME" --image microsoft/aci-helloworld --resource-group "$RESOURCE_GROUP" --ip-address public

4. Confirm creation
`
az container show --name "$CONTAINER_NAME" --resource-group "$RESOURCE_GROUP"
`

5. Pull container logs
`
az container logs --name "$CONTAINER_NAME" --resource-group "$RESOURCE_GROUP"
`

6. Cleanup the resource group
`
az group delete --name "$RESOURCE_GROUP" --yes
az container delete --resource-group "$RESOURCE_GROUP" --name "$CONTAINER_NAME" --yes
`

## Build a container, push it to registry and launch it
https://docs.microsoft.com/en-us/azure/container-instances/container-instances-tutorial-deploy-app
https://github.com/Azure-Samples/aci-helloworld

1. Set Docker Host (https://docs.docker.com/machine/reference/env/)
Check in the Docker Daemon in "General" the setting "Expose daemon on tcp://localhost:2375 without TLS"

`
sudo apt install docker.io
export DOCKER_HOST=tcp://127.0.0.1:2375

`

2. Create container registry
`
REGISTRY_NAME="hellodemo345"
az acr create --resource-group "$RESOURCE_GROUP" --name "$REGISTRY_NAME" --sku Basic --admin-enabled true
`

3. Get login info (eval used because of the double quotation)

Get the registry login server
`
az acr show --name "$REGISTRY_NAME" --query loginServer`
`

Get the login password
`
az acr credential show --name "$REGISTRY_NAME" --query passwords[0].value
`
or automate it

`
DOCKER_SERVER=$(az acr show --name "$REGISTRY_NAME" --query loginServer)
DOCKER_PASSWORD=$(az acr credential show --name "$REGISTRY_NAME" --query passwords[0].value)
eval "docker login --username="$REGISTRY_NAME" --password=$DOCKER_PASSWORD $DOCKER_SERVER"
`
 
4. Pull, tag and push the latest image to the registry


`
docker pull microsoft/aci-helloworld
eval "docker tag microsoft/aci-helloworld $DOCKER_SERVER/aci-helloworld:v1"
eval "docker push $DOCKER_SERVER/aci-helloworld:v1"

or

docker tag microsoft/aci-helloworld hellodemo345.azurecr.io/aci-helloworld:v1
docker push "hellodemo345.azurecr.io/aci-helloworld:v1"

`

5. Clone the source code depot. Build the image and push it to the registry. Run it on a new container instance.
 `
git clone https://github.com/Azure-Samples/aci-helloworld.git
cd aci-helloworld
less Dockerfile
docker build -t aci-tut-app .
docker images
eval "docker tag aci-tut-app $DOCKER_SERVER/aci-tut-app:v1"
eval "docker push $DOCKER_SERVER/aci-tut-app:v1"
CONTAINER_APP_NAME="acihelloworldapp"
az container create -g $RESOURCE_GROUP --name $CONTAINER_APP_NAME --image hellodemo345.azurecr.io/aci-tut-app:v1 --registry-password $DOCKER_PASSWORD

## Automate it by using VSTS
## Create a build process template

1. Create a build process for your git repo
![](/img/2017-08-07-07-44-35.png)

2. Get sources task
![](/img/2017-08-07-07-47-29.png)

3. Build an image task
![](/img/2017-08-07-07-48-22.png)

4. Push an image task
![](/img/2017-08-07-07-48-47.png)

5. Configure the trigger for git repo changes
![](/img/2017-08-07-07-49-50.png)

## Create release process template
Since this has to run on a private agent go for [VSTS Build Agent Setup](VstsSetup.md) and configure one.
The overall launch task is very simple:
![](/img/2017-08-07-07-52-31.png)

1. Take a azure cli task from the marketplace and configure it to use your agent.
![](/img/2017-08-07-07-55-16.png)

2. Configure the azure cli task to use the following arguments:
![](/img/2017-08-07-07-55-56.png)

3. Configure the variables and registry password (put lock on it):
![](/img/2017-08-07-07-56-37.png)
