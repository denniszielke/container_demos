# Deploy voting app


Fix HPA in AKS
https://github.com/Azure/AKS/issues/318
git clone https://github.com/kubernetes-incubator/metrics-server.git
cd metrics-server
kubectl create -f deploy/1.8+/

kubectl delete pod heapster

```
kubectl apply -f https://raw.githubusercontent.com/Azure-Samples/azure-voting-app-redis/master/azure-vote-all-in-one-redis.yaml

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


https://github.com/Azure-Samples/virtual-node-autoscale


export VK_NODE_NAME=virtual-node-aci-linux
export INGRESS_EXTERNAL_IP=13.95.228.243

kubectl -n kube-system get po intended-gopher-nginx-ingress-controller-96c8f95cd-6l5kp -o yaml | grep ingress-class | sed -e 's/.*=//'

export INGRESS_CLASS_ANNOTATION=nginx
helm install stable/grafana --version 1.26.1 --name grafana -f grafana/values.yaml

TkfbbN0KTXrlTGCbpZzPu8NONFv6ZPbZrs9iesr3

export POD_NAME=$(kubectl get pods --namespace default -l "app=grafana" -o jsonpath="{.items[0].metadata.name}")
kubectl --namespace default port-forward $POD_NAME 3000
open http://localhost:3000

az aks get-credentials --resource-group dzburstdemo2 --name dzburst

export GOPATH=~/go
export PATH=$GOPATH/bin:$PATH
go get -u github.com/rakyll/hey
PUBLIC_IP="store.13.95.228.243.nip.io/"
hey -z 20m http://$PUBLIC_IP