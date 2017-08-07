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

4. Create a multi container deployment based of the multi-calculator/deploymultiaci.json
```
CONTAINER_NAME="multicalculator"
az group deployment create --name $CONTAINER_NAME --resource-group $RESOURCE_GROUP --template-file multi-calculator/deploymultiaci.json
```

