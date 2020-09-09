


kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/logging/dummy-logger/pod-logger.yaml
kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/logging/dummy-logger/depl-logger.yaml

kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/logging/dummy-logger/svc-cluster-logger.yaml
kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/logging/dummy-logger/svc-int-logger.yaml
kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/logging/dummy-logger/svc-lb-logger.yaml

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: centos
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

kubectl exec -ti centos -- /bin/bash

SERVICE_IP=$(kubectl get svc azure-vote-front --template="{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}")
for i in {1..1000}; do curl -s -w "%{time_total}\n" -o /dev/null http://$SERVICE_IP; done

KUBENET_PPG
POD_IP=10.244.1.2
SERVICE_IP=10.0.147.134
LB_IP=104.45.65.254

KUBENET_ZONES
POD_IP=10.244.1.3
SERVICE_IP=10.0.33.202
LB_IP=51.138.118.16

for i in {1..1000}; do curl -s -w "%{time_total}\n" -o /dev/null http://$POD_IP; done

for i in {1..1000}; do curl -s -w "%{time_total}\n" -o /dev/null http://$SERVICE_IP; done

for i in {1..1000}; do curl -s -w "%{time_total}\n" -o /dev/null http://$LB_IP; done