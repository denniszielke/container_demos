# Dapr using ServiceBus

KUBE_GROUP=
SB_NAMESPACE=dzdapr$RANDOM
LOCATION=westeurope

az servicebus namespace create --resource-group $KUBE_GROUP --name $SB_NAMESPACE --location $LOCATION

SB_CONNECTIONSTRING=

kubectl delete component messagebus

cat <<EOF | kubectl apply -f -
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: pubsub-azure-service-bus
spec:
  type: pubsub.azure.servicebus
  metadata:
  - name: connectionString
    value: $SB_CONNECTIONSTRING
  - name: timeoutInSec
    value: 60
  - name: maxDeliveryCount
    value: 10
  - name: lockDurationInSec
    value: 3
  - name: defaultMessageTimeToLiveInSec
    value: 2
EOF

kubectl delete component messagebus
kubectl delete component pubsub-azure-service-bus


kubectl logs -l demo=pubsub