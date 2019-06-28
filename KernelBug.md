
```
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

postStart:
  exec:
    command:
    - /bin/sh
    - -c
    - "/bin/echo 'options single-request-reopen' >> /etc/resolv.conf"

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: centoss-deployment6
  labels:
    app: centoss6
spec:
  replicas: 1
  selector:
    matchLabels:
      app: centoss
  template:
    metadata:
      labels:
        app: centoss
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


for i in {1..1000}; do curl -s -w "%{time_total}\n" -o /dev/null http://www.microsoft.com/; done
for i in {1..1000}; do curl -s -w "%{time_total}\n" -o /dev/null http://http://137.117.245.83; done
kubectl delete pod -n kube-system --selector="k8s-app=kube-dns"
kubectl delete  pod -n kube-system --selector="component=azure-cni-networkmonitor"
kubectl delete  pod -n kube-system --selector="component=kube-svc-redirect"
kubectl delete pod centos
kubectl delete deployment centoss-deployment6

while(true); do sleep 1; kubectl  delete pod   -n kube-system  --selector "component=azure-cni-networkmonitor";  done
 component=kube-svc-redirect

sudo apt-get update
sudo apt-get install linux-image-4.15.0-1030-azure 
sudo systemctl reboot


repro cni
kubectl exec -ti centos -- /bin/bash
[root@centos /]# for i in {1..100}; do curl -s -w "%{time_total}\n" -o /dev/null http://www.bing.com/; done
5.593
5.596
0.096
0.101
5.602
0.110

for i in `seq 1 1000`;do time nslookup kubernetes.default; done

We are still getting customer feedback that are complaining about dns timeouts after applying the kernel patch. However what is different that the timeouts are no longer visible in empty clusters - therefore here a set of things I have done to get some load.

I used a centos for testing

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

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: redis
  labels:
    name: redis
spec:
  containers:
  - name: redis
    image: redis:4.0.11-alpine
    args: ["--requirepass", "MySuperSecretRedis"]
    ports:
    - containerPort: 6379
---
apiVersion: v1
kind: Pod
metadata:
  name: rediscli
  labels:
    name: rediscli
spec:
  containers:
  - name: redis
    image: redis
---
apiVersion: v1
kind: Service
metadata:
  name: redis-svc
  labels:
    name: redis-svc
spec:
  selector:
    name: redis
  type: ClusterIP
  ports:
   - port: 6379
     targetPort: 6379
     protocol: TCP
EOF

redis-cli -h redis-svc -p 6379 -a MySuperSecretRedis ping
redis-cli -h redis-svc -p 6379 ping

I also used bing for testing the dns timeout (just in case google was messing with us ;)
kubectl exec -ti centos -- /bin/bash
for i in {1..100}; do curl -s -w "%{time_total}\n" -o /dev/null http://www.google.com/; done

Without the kernel patch the dns timeout occurs like clockwork almost every 5-10 calls
[root@centos /]# for i in {1..100}; do curl -s -w "%{time_total}\n" -o /dev/null http://www.bing.com/; done
5.593
5.596
0.096
0.101
5.602

However after applying the kernel patch and rebooting all nodes I cannot repro the dns timeout on kubenet based clusters (that is promising). However I can repro it on my azure cni based cluster with the following setup (and some load in the cluster).

I need to have some load inside the cluster therefore I launch the azure voting sample
kubectl apply -f https://raw.githubusercontent.com/Azure-Samples/azure-voting-app-redis/master/azure-vote-all-in-one-redis.yaml
Scale the deployment and generate some load 
kubectl scale --replicas=20 deployment/azure-vote-front
kubectl scale --replicas=3 deployment/azure-vote-back

Using chaoskube who is killing random pods after 2 seconds
https://github.com/linki/chaoskube


cat > asdfas <<  EOF

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: chaoskube
spec:
  containers:
  - name: chaoskube
    image: quay.io/linki/chaoskube:v0.11.0
    args:
    # kill a pod every 10 minutes
    - --interval=0m1s
    # only target pods in the test environment
    - --labels=app=azure-vote-front
    # exclude all pods in the kube-system namespace
    - --namespaces=!kube-system
    - --no-dry-run
EOF

In addition some random traffic that is hitting the frontend svc of 
SERVICE_IP=$(kubectl get svc azure-vote-front --template="{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}")
for i in {1..1000}; do curl -s -w "%{time_total}\n" -o /dev/null http://$SERVICE_IP; done

Now after running the centos I can get a dns timeout for one in 300 curls to bing running this.

var=1;
while true ; do
  res=$( { curl -o /dev/null -s -w %{time_namelookup}\\n  http://www.bing.com; } 2>&1 )
  var=$((var+1))
  now=$(date +"%T")
  if [[ $res =~ ^[1-9] ]]; then
    now=$(date +"%T")
    echo "$var slow: $res $now"
    break
  fi
done

var=1;
while true ; do
  res=$( { curl -o /dev/null -s -w %{time_namelookup}\\n  http://www.bing.com; } 2>&1 )
  var=$((var+1))
  now=$(date +"%T")
  if [[ $res =~ ^[1-9] ]]; then
    now=$(date +"%T")
    echo "$var slow: $res $now"
    break
  fi
done

[root@centos /]# while true ; do   res=$( { curl -o /dev/null -s -w %{time_namelookup}\\n  http://www.bing.com; } 2>&1 );   var=$((var+1));   now=$(date +"%T");   if [[ $res =~ ^[1-9] ]]; then     now=$(date +"%T");     echo "$var slow: $res $now";     break;   fi; done
183 slow: 10.517 22:09:27
[root@centos /]# while true ; do   res=$( { curl -o /dev/null -s -w %{time_namelookup}\\n  http://www.bing.com; } 2>&1 );   var=$((var+1));   now=$(date +"%T");   if [[ $res =~ ^[1-9] ]]; then     now=$(date +"%T");     echo "$var slow: $res $now";     break;   fi; done
204 slow: 10.519 22:10:28
```
