# Show services

Build and publish blue and green images

```
docker tag blue dzregistry.azurecr.io/blue
docker push dzregistry.azurecr.io/blue
docker tag green dzregistry.azurecr.io/green
docker push dzregistry.azurecr.io/green
```

