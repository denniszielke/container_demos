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

kubectl scale --replicas=5 deployment/azure-vote-front

kubectl autoscale deployment azure-vote-front --cpu-percent=20 --min=2 --max=10


kubectl get hpa


kubectl run -it busybox-replicas --rm --image=busybox -- sh

for i in 1 2 3 4 5; do
wget -q -O- http://azure-vote-front
done

kubectl run -it busybox-replicas --rm --image=busybox -- sh

for i in 1 2 3 4 5; do
wget -q -O- http://web:8080
done

for i in {1..200} \ do \    wget -q -O- "http://azure-vote-front?i="$i \ done


for i in {1..100}

wget -q -O- http://azure-vote-front?{1..200}

```

Create a webtest and use application insights
https://azure.microsoft.com/en-us/blog/creating-a-web-test-alert-programmatically-with-application-insights/