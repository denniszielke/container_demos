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

helm install --name vn-affinity ./charts/vn-affinity-admission-controller

kubectl label namespace default vn-affinity-injection=enabled --overwrite


export VK_NODE_NAME=virtual-node-aci-linux
export INGRESS_EXTERNAL_IP=13.69.125.59
export INGRESS_CLASS_ANNOTATION=nginx


helm install ./charts/online-store --name online-store --set counter.specialNodeName=$VK_NODE_NAME,app.ingress.host=store.$INGRESS_EXTERNAL_IP.nip.io,appInsight.enabled=false,app.ingress.annotations."kubernetes\.io/ingress\.class"=$INGRESS_CLASS_ANNOTATION --namespace store 

kubectl -n kube-system get po nginx-ingress-controller-7db8d69bcc-t5zww -o yaml | grep ingress-class | sed -e 's/.*=//'


helm install stable/grafana --version 1.26.1 --name grafana -f grafana/values.yaml

kubectl get secret --namespace default grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

5D7bs0dkBOxvutbEbpGBHRghxMhCWAuHyyYXawfH

export POD_NAME=$(kubectl get pods --namespace default -l "app=grafana" -o jsonpath="{.items[0].metadata.name}")
kubectl --namespace default port-forward $POD_NAME 3000
open http://localhost:3000

az aks get-credentials --resource-group dzburstdemo2 --name dzburst

export GOPATH=~/go
export PATH=$GOPATH/bin:$PATH
go get -u github.com/rakyll/hey
PUBLIC_IP="store.13.95.228.243.nip.io/"
hey -z 20m http://$PUBLIC_IP


# Keda
https://github.com/kedacore/sample-hello-world-azure-functions

KEDA_STORAGE=dzmesh33
LOCATION=westeurope

az group create -l $LOCATION -n $KUBE_GROUP
az storage account create --sku Standard_LRS --location $LOCATION -g $KUBE_GROUP -n $KEDA_STORAGE

CONNECTION_STRING=$(az storage account show-connection-string --name $KEDA_STORAGE --query connectionString)

az storage queue create -n js-queue-items --connection-string $CONNECTION_STRING

az storage account show-connection-string --name $KEDA_STORAGE --query connectionString

kubectl create namespace keda-app
helm install --name vn-affinity ./charts/vn-affinity-admission-controller

kubectl label namespace keda vn-affinity-injection=disabled --overwrite

KEDA_NS=keda-app
KEDA_IN=hello-keda

func kubernetes install --namespace $KEDA_NS

func kubernetes deploy --name $KEDA_IN --registry denniszielke --namespace $KEDA_NS --polling-interval 5 --cooldown-period 30

kubectl get ScaledObject $KEDA_IN --namespace $KEDA_NS -o yaml

kubectl delete deploy $KEDA_IN --namespace $KEDA_NS
kubectl delete ScaledObject $KEDA_IN --namespace $KEDA_NS
kubectl delete Secret $KEDA_IN --namespace $KEDA_NS

helm install --name vn-affinity ./charts/vn-affinity-admission-controller
kubectl label namespace default vn-affinity-injection=enabled


helm install ./charts/online-store --name online-store --set counter.specialNodeName=$VK_NODE_NAME,app.ingress.host=store.$INGRESS_EXTERNAL_IP.nip.io,appInsight.enabled=false,app.ingress.annotations."kubernetes\.io/ingress\.class"=$INGRESS_CLASS_ANNOTATION

