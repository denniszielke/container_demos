# Hello World Services



# Show services

1. Build and publish blue and green images to registry

```
docker tag blue dzregistry.azurecr.io/blue
docker push dzregistry.azurecr.io/blue
docker tag green dzregistry.azurecr.io/green
docker push dzregistry.azurecr.io/green
```

2. Deploying Pods & Services
```
kubectl create -f blue-pod.yml
kubectl create -f frontend-svc.yml
kubectl create -f green-pod.yml
```

3. Delete the green pod
```
kubectl delete pod greendemo
```

4. Scale the blue pods via replication controller
~~~
kubectl create -f blue-rc.yml
~~~

5. See rolling upgrades
~~~
kubectl apply -f deployment.yml --record
~~~

6. Check as the upgrade happens
~~~
watch kubectl get pods --show-labels
~~~ 

7. Check status of replicaset
~~~
kubectl get rs
~~~

8. See deployment history
~~~
kubectl rollout history -f deployment.yml
~~~

9. Check status of replicaset
~~~
kubectl get rs
~~~ 

10. Rollback deployment 
~~~ 
kubectl rollout undo -f deployment.yml
~~~

~~~
watch kubectl get pods --show-labels
~~~

