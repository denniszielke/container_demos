# Pod Security policy

0. Variables
```

KUBE_GROUP="KubePSPs"
KUBE_NAME="kubesecurity"
LOCATION="westeurope"
KUBE_VERSION="1.12.6"
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