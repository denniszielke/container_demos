# Build container

https://github.com/Azure-Samples/docker-django-webapp-linux

Build the image
```
git clone https://github.com/Azure-Samples/docker-django-webapp-linux.git

cd docker-django-webapp-linux

docker login $REGISTRY_URL -u $REGISTRY_NAME -p $REGISTRY_PASSWORD

docker build -t django .
```

Test the images

```
docker run django -e "WEBSITE_PORT=8000"
```

Tag and push the image to our registry
```
docker tag django dzregistry.azurecr.io/web/django
docker push dzregistry.azurecr.io/web/django
```

# Create web app
https://docs.microsoft.com/en-us/azure/app-service/scripts/app-service-cli-linux-docker-aspnetcore?toc=%2fcli%2fazure%2ftoc.json

az account set --subscription $SUBSCRIPTION_ID
docker login $REGISTRY_URL -u $REGISTRY_NAME -p $REGISTRY_PASSWORD

az group create --name $WEBAPP_GROUP --location $LOCATION

az appservice plan create --name $WEBAPP_PLAN --resource-group $WEBAPP_GROUP --location $LOCATION --is-linux --sku S1

az webapp create --name $WEBAPP_NAME --plan $WEBAPP_PLAN --resource-group $WEBAPP_GROUP --runtime "node|8.1"

az webapp config appsettings set -g $WEBAPP_GROUP -n $WEBAPP_NAME --settings WEBSITE_PORT=8000

az webapp config container set --docker-custom-image-name $DJANGO_PATH --docker-registry-server-password $REGISTRY_PASSWORD --docker-registry-server-url $REGISTRY_URL --docker-registry-server-user $REGISTRY_NAME --name $WEBAPP_NAME --resource-group $WEBAPP_GROUP

az group delete --name $WEBAPP_GROUP