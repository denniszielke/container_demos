# Kubernetes best practices

Kubectl cheat sheet
https://kubernetes.io/docs/reference/kubectl/cheatsheet/



## Working with quotas for namespaces

Create a resource quota for your namespace
```
kubectl create -f ./bestpractices/compute-resources.yaml --namespace=NAMESPACE
```

## Implement network segmentation in the cluster


