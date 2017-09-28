# Show services

Build and publish blue and green images

```
docker tag blue dzregistry.azurecr.io/blue
docker push dzregistry.azurecr.io/blue
docker tag green dzregistry.azurecr.io/green
docker push dzregistry.azurecr.io/green
```

Deploy individual pods
kubectl create -f blue-pod.yml
kubectl create -f frontend-svc.yml
kubectl create -f green-pod.yml

kubectl delete pod greendemo

kubectl create -f blue-rc.yml

kubectl apply -f deployment.yml --record

watch kubectl get pods --show-labels

Check status of replicaset
kubectl get rs

See deployment history
kubectl rollout history -f deployment.yml

Check status of replicaset
kubectl get rs

kubectl rollout undo -f deployment.yml

watch kubectl get pods --show-labels