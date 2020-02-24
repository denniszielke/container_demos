# Setting up Kafka
https://github.com/dapr/samples/tree/master/5.bindings

helm repo add incubator http://storage.googleapis.com/kubernetes-charts-incubator
helm repo update
kubectl create namespace kafka
helm install dapr-kafka --namespace kafka incubator/kafka --set replicas=1

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