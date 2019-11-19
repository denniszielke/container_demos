# Deploy voting app

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

# Virtual node autoscaling
https://github.com/Azure-Samples/virtual-node-autoscale

```
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
```

# Keda
https://github.com/kedacore/sample-hello-world-azure-functions

```
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
```

## Cluster autoscaler test

```
kubectl run nginx --image=nginx --requests=cpu=1000m,memory=1024Mi --expose --port=80 --replicas=5
kubectl scale deployment nginx --replicas=10
```


while true; do sleep 1; curl http://10.0.1.14/ping; echo -e '\n\n\n\n'$(date);done

az network lb rule list --lb-name kubernetes-internal --resource-group kub_ter_a_m_scaler2_nodes_westeurope

[
  {
    "backendAddressPool": {
      "id": "/subscriptions/5abd8123-18f8-427f-a4ae-30bfb82617e5/resourceGroups/kub_ter_a_m_scaler2_nodes_westeurope/providers/Microsoft.Network/loadBalancers/kubernetes-internal/backendAddressPools/kubernetes",
      "resourceGroup": "kub_ter_a_m_scaler2_nodes_westeurope"
    },
    "backendPort": 80,
    "disableOutboundSnat": true,
    "enableFloatingIp": true,
    "enableTcpReset": false,
    "etag": "W/\"bbe57a78-66f4-440a-afcb-510577c2e476\"",
    "frontendIpConfiguration": {
      "id": "/subscriptions/5abd8123-18f8-427f-a4ae-30bfb82617e5/resourceGroups/kub_ter_a_m_scaler2_nodes_westeurope/providers/Microsoft.Network/loadBalancers/kubernetes-internal/frontendIPConfigurations/a13c54ea6e04e11e984ea82987248e36-ing-4-subnet",
      "resourceGroup": "kub_ter_a_m_scaler2_nodes_westeurope"
    },
    "frontendPort": 80,
    "id": "/subscriptions/5abd8123-18f8-427f-a4ae-30bfb82617e5/resourceGroups/kub_ter_a_m_scaler2_nodes_westeurope/providers/Microsoft.Network/loadBalancers/kubernetes-internal/loadBalancingRules/a13c54ea6e04e11e984ea82987248e36-ing-4-subnet-TCP-80",
    "idleTimeoutInMinutes": 4,
    "loadDistribution": "Default",
    "name": "a13c54ea6e04e11e984ea82987248e36-ing-4-subnet-TCP-80",
    "probe": {
      "id": "/subscriptions/5abd8123-18f8-427f-a4ae-30bfb82617e5/resourceGroups/kub_ter_a_m_scaler2_nodes_westeurope/providers/Microsoft.Network/loadBalancers/kubernetes-internal/probes/a13c54ea6e04e11e984ea82987248e36-ing-4-subnet-TCP-80",
      "resourceGroup": "kub_ter_a_m_scaler2_nodes_westeurope"
    },
    "protocol": "Tcp",
    "provisioningState": "Succeeded",
    "resourceGroup": "kub_ter_a_m_scaler2_nodes_westeurope",
    "type": "Microsoft.Network/loadBalancers/loadBalancingRules"
  }
]


az network lb rule update  --name a13c54ea6e04e11e984ea82987248e36-ing-4-subnet-TCP-80 --lb-name kubernetes-internal --resource-group kub_ter_a_m_scaler2_nodes_westeurope --enable-tcp-reset true


az network lb rule list --lb-name kubernetes-internal --resource-group kub_ter_a_m_scaler_nodes_westeurope

az network lb rule update  --name a69b6ac41e04e11e98bc46e0d4f805cb-ing-4-subnet-TCP-80 --lb-name kubernetes-internal --resource-group kub_ter_a_m_scaler_nodes_westeurope --enable-tcp-reset true