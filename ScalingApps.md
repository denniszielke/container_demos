# Deploy voting app


Fix HPA in AKS
https://github.com/Azure/AKS/issues/318
git clone https://github.com/kubernetes-incubator/metrics-server.git
cd metrics-server
kubectl create -f deploy/1.8+/

kubectl delete pod heapster

```
kubectl create -f https://raw.githubusercontent.com/Azure-Samples/azure-voting-app-redis/master/azure-vote-all-in-one-redis.yaml

kubectl get pod -o wide

kubectl scale --replicas=6 deployment/azure-vote-front
kubectl scale --replicas=4 deployment/azure-vote-back

kubectl autoscale deployment azure-vote-front --cpu-percent=20 --min=20 --max=30


kubectl get hpa


kubectl run -it busybox-replicas --rm --image=busybox -- sh

for i in 1 2 3 4 5; do
wget -q -O- http://azure-vote-front
done

kubectl run -it busybox-replicas --rm --image=busybox -- sh

for i in 1 ... 1000; do \ 
wget -q -O- http://65.52.144.134 \
done
for i in `seq 1 100`; do time curl -s http://40.85.173.109 > /dev/null; done

for i in {1...200} \ do \    curl -q -O- "http://azure-vote-front?i="$i \ done

while true; do sleep 1; curl http://40.85.173.109; echo -e '\n\n\n\n'$(date);done


for i in {1..2000}

wget -q -O- http://65.52.144.134?{1..2000}

```

Create a webtest and use application insights
https://azure.microsoft.com/en-us/blog/creating-a-web-test-alert-programmatically-with-application-insights/


flexlab/azure-mesh-fireworks-worker-v2

OBJECT_TYPE=RED