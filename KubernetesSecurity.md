# Limit administrative access
https://github.com/kubernetes/dashboard/wiki/Creating-sample-user 

create user
```
cat <<EOF | kubectl create -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kube-system
EOF
```

create cluster role binding
```
cat <<EOF | kubectl create -f -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kube-system
EOF
```

after 1.8
```
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: my-dashboard-sa
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: my-dashboard-sa
  namespace: kube-system
```

create bearer token
```
kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep edit-user | awk '{print $1}')

kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep my-dashboard-sa | awk '{print $1}')
```

Set kubectl context
```
kubectl config set-cluster low-cluster --server=$KUBE_MANAGEMENT_ENDPOINT --insecure-skip-tls-verify=true

kubectl config set-credentials edit-user --token=$TOKEN

kubectl config set-context low-context --cluster=low-cluster --user=edit-user

kubectl config use-context low-context
```

## Lock down api server
https://github.com/Azure/azure-cli-extensions/tree/master/src/aks-preview#enable-apiserver-authorized-ip-ranges

MYIP=$(curl ipinfo.io/ip)

KUBE_GROUP="kubvmss"
KUBE_NAME="dzkubvmss"

az aks update -g $KUBE_GROUP  -n $KUBE_NAME --api-server-authorized-ip-ranges "$MYIP"

az aks list -g $KUBE_GROUP -n $KUBE_NAME

## Minimum roles

https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles