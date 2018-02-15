# Limit administrative access
https://github.com/kubernetes/dashboard/wiki/Creating-sample-user 

create user
```
apiVersion: v1
kind: ServiceAccount
metadata:
  name: edit-user
  namespace: kube-system
```

create cluster role binding
```
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: edit-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: admin
subjects:
- kind: ServiceAccount
  name: edit-user
  namespace: kube-system
```

create bearer token
kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep edit-user | awk '{print $1}')


Set kubectl context
```
kubectl config set-cluster low-cluster --server=$KUBE_MANAGEMENT_ENDPOINT--insecure-skip-tls-verify=true

kubectl config set-credentials edit-user --token=$TOKEN

kubectl config set-context low-context --cluster=low-cluster --user=edit-user

kubectl config use-context low-context
```