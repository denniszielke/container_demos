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

helm install --name $APP_INSTANCE incubator/kafka --set global.namespace=$APP_NAME --tiller-namespace $APP_NAME --namespace $APP_NAME
Error: release mykafka failed: poddisruptionbudgets.policy is forbidden: User "system:serviceaccount:kafka:tiller-kafka" cannot create poddisruptionbudgets.policy in the namespace "kafka"

```

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: testclient
  namespace: kafka
spec:
  containers:
  - name: kafka
    image: confluentinc/cp-kafka:5.0.1
    command:
      - sh
      - -c
      - "exec tail -f /dev/null"
EOF

find / -type f -name kafka-topics.sh


Once you have the testclient pod above running, you can list all kafka
topics with:

  kubectl -n kafka exec testclient -- /opt/kafka/bin/kafka-topics.sh --zookeeper my-kafka-zookeeper:2181 --list

To create a new topic:

  kubectl -n kafka exec testclient -- /opt/kafka/bin/kafka-topics.sh --zookeeper my-kafka-zookeeper:2181 --topic test1 --create --partitions 1 --replication-factor 1

To listen for messages on a topic:

  kubectl -n kafka exec -ti testclient -- /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server my-kafka:9092 --topic test1 --from-beginning

To stop the listener session above press: Ctrl+C

To start an interactive message producer session:
  kubectl -n kafka exec -ti testclient -- /opt/kafka/bin/kafka-console-producer.sh --broker-list my-kafka-headless:9092 --topic test1

To create a message in the above session, simply type the message and press "enter"
To end the producer session try: Ctrl+C