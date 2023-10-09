# Fleet
https://learn.microsoft.com/en-gb/azure/kubernetes-fleet/quickstart-create-fleet-and-members

GROUP=fleet
FLEET=fleet
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

az group create --name ${GROUP} --location eastus

az fleet create --resource-group ${GROUP} --name ${FLEET} --location eastus


az fleet get-credentials --resource-group ${GROUP}  --name ${FLEET} --file $HOME/.kube/fleet

az aks get-credentials --resource-group FL_dfleet_fleet_eastus --name hub --admin --file $HOME/.kube/fleet
export KUBECONFIG=$HOME/.kube/fleet

export KUBECONFIG=$HOME/.kube/dzfleet4
export KUBECONFIG=$HOME/.kube/dzfleet5

kubectl create namespace kuard-demo

export FLEET_ID=/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${GROUP}/providers/Microsoft.ContainerService/fleets/fleet
export IDENTITY=$(az ad signed-in-user show --query "id" --output tsv)
export ROLE="Azure Kubernetes Fleet Manager RBAC Cluster Admin"
az role assignment create --role "${ROLE}" --assignee ${IDENTITY} --scope ${FLEET_ID}


az aks get-credentials --resource-group $KUBE_GROUP --name $KUBE_NAME --admin --file $HOME/.kube/$KUBE_NAME
export KUBECONFIG=$HOME/.kube/$KUBE_NAME

cat <<EOF | kubectl apply -f -
apiVersion: fleet.azure.com/v1alpha1
kind: ClusterResourcePlacement
metadata:
  name: kuard-demo
spec:
  resourceSelectors:
    - group: ""
      version: v1
      kind: Namespace
      name: kuard-demo
  policy:
    affinity:
      clusterAffinity:
        clusterSelectorTerms:
          - labelSelector:
              matchLabels:
                fleet.azure.com/location: uksouth
EOF

kubectl get serviceexport kuard --namespace kuard-demo
kubectl get serviceexport kuard --namespace kuard-demo
kubectl apply -f https://raw.githubusercontent.com/Azure/AKS/master/examples/fleet/kuard/kuard-mcs.yaml
kubectl get multiclusterservice kuard --namespace kuard-demo


az aks get-credentials --resource-group dzlinked5 --name dzlinked5 --admin --file dzlinked5
export KUBECONFIG=`pwd`/dzlinked5

# Calculator

kubectl create namespace calculator-frontend
kubectl create namespace calculator-backend

cat <<EOF | kubectl apply -f -
apiVersion: fleet.azure.com/v1alpha1
kind: ClusterResourcePlacement
metadata:
  name: calculator-frontend
spec:
  resourceSelectors:
    - group: ""
      version: v1
      kind: Namespace
      name: calculator-frontend
  policy:
    affinity:
      clusterAffinity:
        clusterSelectorTerms:
          - labelSelector:
              matchLabels:
                fleet.azure.com/location: eastus
EOF

cat <<EOF | kubectl apply -f -
apiVersion: fleet.azure.com/v1alpha1
kind: ClusterResourcePlacement
metadata:
  name: calculator-backend
spec:
  resourceSelectors:
    - group: ""
      version: v1
      kind: Namespace
      name: calculator-backend
  policy:
    clusterNames:
      - dzfleet5
      - dzfleet4
EOF

cat <<EOF | kubectl apply -f -
apiVersion: fleet.azure.com/v1alpha1
kind: ClusterResourcePlacement
metadata:
  name: calculator-backend
spec:
  resourceSelectors:
    - group: ""
      version: v1
      kind: Namespace
      name: calculator-backend
  policy:
    affinity:
      clusterAffinity:
        clusterSelectorTerms:
          - labelSelector:
              matchLabels:
                fleet.azure.com/location: eastus
EOF

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: centos
spec:
  containers:
  - name: centos
    image: centos
    ports:
    - containerPort: 80
    command:
    - sleep
    - "3600"
EOF

kubectl get clusterresourceplacements

cat <<EOF | kubectl apply -f -
apiVersion: networking.fleet.azure.com/v1alpha1
kind: ServiceExport
metadata:
  name: http-backend
  namespace: calculator-backend
EOF

kubectl get serviceexport --namespace calculator-backend

cat <<EOF | kubectl apply -f -
apiVersion: networking.fleet.azure.com/v1alpha1
kind: MultiClusterService
metadata:
  name: http-backend
  namespace: calculator-backend
spec:
  serviceImport:
    name: http-backend
EOF

kubectl get multiclusterservice  -A


kubectl exec -it centos -- /bin/bash
curl http-backend.calculator-backend.svc.clusterset.local 