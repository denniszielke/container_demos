

NODE_GROUP=MC_kub_ter_a_m_scale51_scale51_westeurope
IP_NAME=



IP=$(az network public-ip show --resource-group $NODE_GROUP --name $IP_NAME --query ipAddress --output tsv)

az network public-ip list --resource-group $NODE_GROUP --output json --query '[].{IP:ipAddress, tags:tags}'

i=100;
while true ; do
  echo "starting creating lb $i"
  SVC_NAME=dummy-cl-$i
  echo "
apiVersion: v1
kind: Service
metadata:
  name: dummy-cl-$i
spec:
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: dummy-logger
  type: LoadBalancer
" | kubectl apply -f -
  external_ip=""
  while [ -z $external_ip ]; do
    sleep 10
    echo "waiting for dummy-cl-$i"
    external_ip=$(kubectl get svc dummy-cl-$i --template="{{range .status.loadBalancer.ingress}}{{.ip}}{{end}}")
  done
  echo "got public ip $external_ip for dummy-cl-$i"
  az network public-ip list --resource-group $NODE_GROUP --output json --query '[].{IP:ipAddress, tags:tags}' | jq '.[] | select(.IP=="$external_ip")'
  echo "deleting dummy-cl-$i with $external_ip"
  kubectl delete svc dummy-cl-$i
  externalIpExists=$external_ip
  while [ ! -z $externalIpExists ]; do
    sleep 10
    echo "waiting for dummy-cl-$i and $external_ip to delete"
    externalIpExists=$(az network public-ip list --resource-group $NODE_GROUP --output json --query '[].{IP:ipAddress, tags:tags}' | jq | grep $external_ip)
  done
  echo "deleted $external_ip"
  i=$((i+1))
  now=$(date +"%T")
  echo "starting again at $now with $i"
done


external_ip=""
i=1
SVC_NAME=dummy-cl-$i

kubectl get svc $SVC_NAME -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

while [ -z $external_ip ]; do
    sleep 10
    echo "waiting for $SVC_NAME"
    external_ip=$(kubectl get svc $SVC_NAME -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
done

az network public-ip show --resource-group $NODE_GROUP --output json