# Dapr using ServiceBus

KUBE_GROUP=
HUB_NAMESPACE=dzdapr$RANDOM
LOCATION=westeurope

az eventhubs namespace create --name $HUB_NAMESPACE --resource-group $KUBE_GROUP

az eventhubs eventhub create --name events --resource-group $KUBE_GROUP --namespace-name $HUB_NAMESPACE

az eventhubs namespace authorization-rule keys list --name RootManageSharedAccessKey --namespace-name $HUB_NAMESPACE --resource-group $KUBE_GROUP --query "primaryConnectionString" | tr -d '"'

HUB_CONNECTIONSTRING=$(az eventhubs namespace authorization-rule keys list --name RootManageSharedAccessKey --namespace-name $HUB_NAMESPACE --resource-group $KUBE_GROUP --query "primaryConnectionString" | tr -d '"')


kubectl delete component eventhubs-input

cat <<EOF | kubectl apply -f -
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: eventhubs-input
spec:
  type: bindings.azure.eventhubs
  metadata:
  - name: connectionString
    value: $HUB_CONNECTIONSTRING
EOF

kubectl delete component eventhubs-input
kubectl delete component eventhubs-input


kubectl logs -l demo=pubsub


curl -X POST http://localhost:3500/v1.0/publish/deathStarStatus \
	-H "Content-Type: application/json" \
	-d '{
       	     "status": "completed"
      	}'