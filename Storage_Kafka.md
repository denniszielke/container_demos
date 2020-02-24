# Using Helm
https://github.com/kubernetes/charts/tree/master/incubator/kafka

## Install Helm for rbac

```
APP_NAME=kafka
APP_INSTANCE=mykafka
kubectl create ns $APP_NAME
helm repo add incubator http://storage.googleapis.com/kubernetes-charts-incubator
helm repo update
kubectl create namespace kafka
helm install dapr-kafka --namespace kafka incubator/kafka --set replicas=1
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