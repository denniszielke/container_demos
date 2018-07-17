# Using Helm
https://github.com/kubernetes/charts/tree/master/incubator/kafka

## Install Helm for rbac

```
APP_NAME=kafka
APP_INSTANCE=mykafka
kubectl create ns $APP_NAME
kubectl create serviceaccount tiller-$APP_NAME -n $APP_NAME

cat <<EOF | kubectl create -f -
kind: Role
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: $APP_NAME-manager
  namespace: $APP_NAME
rules:
- apiGroups: ["", "extensions", "apps"]
  resources: ["*"]
  verbs: ["*"]
EOF

cat <<EOF | kubectl create -f -
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: $APP_NAME-binding
  namespace: $APP_NAME
subjects:
- kind: ServiceAccount
  name: tiller-$APP_NAME
  namespace: $APP_NAME
roleRef:
  kind: Role
  name: $APP_NAME-manager
  apiGroup: rbac.authorization.k8s.io
EOF

helm init --service-account tiller-$APP_NAME --tiller-namespace $APP_NAME

helm repo add incubator http://storage.googleapis.com/kubernetes-charts-incubator --tiller-namespace $APP_NAME

helm install --name $APP_INSTANCE incubator/kafka --set global.namespace=$APP_NAME --tiller-namespace $APP_NAME --namespace $APP_NAME

  labs helm install --name $APP_INSTANCE incubator/kafka --set global.namespace=$APP_NAME --tiller-namespace $APP_NAME --namespace $APP_NAME
Error: release mykafka failed: poddisruptionbudgets.policy is forbidden: User "system:serviceaccount:kafka:tiller-kafka" cannot create poddisruptionbudgets.policy in the namespace "kafka"

```