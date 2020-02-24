# Pod Security policy
https://docs.bitnami.com/kubernetes/how-to/secure-kubernetes-cluster-psp/
https://kubernetes.io/docs/concepts/policy/pod-security-policy/

0. Variables
```

KUBE_GROUP="KubePSPs"
KUBE_NAME="kubesecurity"
LOCATION="westeurope"
KUBE_VERSION="1.12.7"
CLUSTER_NAME="security"

az group create -n $KUBE_GROUP -l $LOCATION

az aks update -g $KUBE_GROUP -n $KUBE_NAME --enable-pod-security-policy

az group deployment create \
    --name pspaks101 \
    --resource-group $KUBE_GROUP \
    --template-file "arm/psp_template.json" \
    --parameters "arm/psp_parameters.json" \
    --parameters "resourceName=$KUBE_NAME" \
        "location=$LOCATION" \
        "dnsPrefix=$KUBE_NAME" \
        "servicePrincipalClientId=$SERVICE_PRINCIPAL_ID" \
        "servicePrincipalClientSecret=$SERVICE_PRINCIPAL_SECRET" \
        "kubernetesVersion=$KUBE_VERSION"

KUBE_GROUP="$(az aks list -o tsv | grep $CLUSTER_NAME | cut -f15)"
KUBE_NAME="$(az aks list -o tsv | grep $CLUSTER_NAME | cut -f4)"

```

5. Export the kubectrl credentials files
```
az aks get-credentials --resource-group=$KUBE_GROUP --name=$KUBE_NAME

```

1. Create psp

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: centos1
spec:
  containers:
  - name: centoss
    image: centos
    ports:
    - containerPort: 80
    command:
    - sleep
    - "3600"
EOF
kubectl exec -ti centos1 -- /bin/bash

kubectl get psp
kubectl get clusterrolebindings default:restricted -o yaml

kubectl create namespace psp-aks
kubectl create serviceaccount --namespace psp-aks nonadmin-user
kubectl create rolebinding --namespace psp-aks psp-aks-editor --clusterrole=edit --serviceaccount=psp-aks:nonadmin-user

kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/bestpractices/mountsp.yaml --as=system:serviceaccount:psp-aks:nonadmin-user -n psp-aks

alias kubectl-admin='kubectl --namespace psp-aks'
alias kubectl-nonadminuser='kubectl --as=system:serviceaccount:psp-aks:nonadmin-user --namespace psp-aks'

cat <<EOF | kubectl apply --as=system:serviceaccount:psp-aks:nonadmin-user --namespace psp-aks -f -
apiVersion: v1
kind: Pod
metadata:
  name: nginx-privileged
spec:
  containers:
    - name: nginx-privileged
      image: nginx:1.14.2
      securityContext:
        privileged: true
EOF

cat <<EOF | kubectl apply --as=system:serviceaccount:psp-aks:nonadmin-user --namespace psp-aks -f -
apiVersion: v1
kind: Pod
metadata:
  name: nginx-unprivileged
spec:
  containers:
    - name: nginx-unprivileged
      image: nginx:1.14.2
EOF

cat <<EOF | kubectl apply --as=system:serviceaccount:psp-aks:nonadmin-user --namespace psp-aks -f -
apiVersion: v1
kind: Pod
metadata:
  name: nginx-unprivileged-high-port
  labels:
    nginx: unprivileged
spec:
  containers:
    - name: nginx-unprivileged-high-port
      image: nginx:1.14.2
      env:
        - name: NGINX_PORT
          value: "3000"
      ports:
        - containerPort: 3000
      securityContext:
        runAsUser: 2000
EOF


cat <<EOF | kubectl apply --as=system:serviceaccount:psp-aks:nonadmin-user --namespace psp-aks -f -
apiVersion: v1
kind: Service
metadata:
  labels:
    nginx: unprivileged
  name: nginx-unprivileged
spec:
  ports:
  - port: 80
    protocol: TCP
    targetPort: 8080
  selector:
    nginx: unprivileged
  sessionAffinity: None
  type: LoadBalancer
EOF

kubectl delete svc nginx-unprivileged -n psp-aks

kubectl logs nginx-unprivileged-high-port -n psp-aks

kubectl delete pod nginx-unprivileged-high-port -n psp-aks

cat <<EOF | kubectl apply --as=system:serviceaccount:psp-aks:nonadmin-user --namespace psp-aks -f -
apiVersion: v1
kind: Pod
metadata:
  name: bitnami-nginx-unprivileged-high-port
  labels:
    nginx: unprivileged
spec:
  containers:
    - name: bitnami-nginx-unprivileged-high-port
      image: bitnami/nginx
      ports:
        - containerPort: 8080
      securityContext:
        runAsUser: 2000
EOF

kubectl delete pod bitnami-nginx-unprivileged-high-port -n psp-aks

cat <<EOF | kubectl apply -f -
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: psp-deny-privileged
spec:
  privileged: false
  seLinux:
    rule: RunAsAny
  supplementalGroups:
    rule: RunAsAny
  runAsUser:
    rule: RunAsAny
  fsGroup:
    rule: RunAsAny
  volumes:
  - '*'
EOF

cat <<EOF | kubectl apply -f -
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: psp-deny-privileged-clusterrole
rules:
- apiGroups:
  - extensions
  resources:
  - podsecuritypolicies
  resourceNames:
  - psp-deny-privileged
  verbs:
  - use
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: psp-deny-privileged-clusterrolebinding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: psp-deny-privileged-clusterrole
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: Group
  name: system:serviceaccounts
EOF

2. Try to launch priviledged pod

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: nginx-privileged
  labels:
    run: nginx
spec:
  containers:
    - name: nginx-privileged
      image: nginx:1.14.2
      securityContext:
        privileged: true
EOF

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: nginx-unprivileged
  labels:
    run: nginx
spec:
  containers:
    - name: nginx-unprivileged
      image: nginx:1.14.2
EOF



# Delete everything
```
az aks update-cluster -g $KUBE_GROUP -n $KUBE_NAME --disable-pod-security-policy
```