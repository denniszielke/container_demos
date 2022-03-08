# Cillium

## CLI


```



```

## Install
https://docs.cilium.io/en/latest/gettingstarted/k8s-install-aks/
curl -L --remote-name-all https://github.com/cilium/cilium-cli/releases/download/v0.10.0/cilium-darwin-amd64.tar.gz
shasum -a 256 -c cilium-darwin-amd64.tar.gz.sha256sum
sudo tar xzvfC cilium-darwin-amd64.tar.gz /usr/local/bin
rm cilium-darwin-amd64.tar.gz{,.sha256sum}
```

SUBSCRIPTION_ID=$(az account show --query id -o tsv) 
TENANT_ID=$(az account show --query tenantId -o tsv)
NODE_GROUP=$(az aks show --resource-group $KUBE_GROUP --name $KUBE_NAME --query nodeResourceGroup -o tsv)
SERVICE_PRINCIPAL_ID=$(az ad sp create-for-rbac --skip-assignment --name $KUBE_NAME-sp -o json | jq -r '.appId')
echo $SERVICE_PRINCIPAL_ID

SERVICE_PRINCIPAL_SECRET=$(az ad app credential reset --id $SERVICE_PRINCIPAL_ID -o json | jq '.password' -r)
echo $SERVICE_PRINCIPAL_SECRET

RG_ID=$(az group show -n $KUBE_GROUP --query id -o tsv)
NODE_RG_ID=$(az group show -n $NODE_GROUP --query id -o tsv)

az role assignment create --role "Contributor" --assignee $SERVICE_PRINCIPAL_ID --scope $RG_ID -o none

az role assignment create --role "Contributor" --assignee $SERVICE_PRINCIPAL_ID --scope $NODE_RG_ID -o none


az role assignment create --role "Reader" --assignee 21e02cfc-b6dc-4727-b1b5-bbe200f08dd9 --scope $RG_ID -o none



nodepool_to_delete=$(az aks nodepool list --resource-group $KUBE_GROUP --cluster-name $KUBE_NAME --output tsv --query "[0].name")

az aks nodepool add --resource-group $KUBE_GROUP --cluster-name $KUBE_NAME \
            --name systempool \
            --mode system \
            --node-count 1 \
            --node-taints "CriticalAddonsOnly=true:NoSchedule" \
            --no-wait

az aks nodepool add --resource-group $KUBE_GROUP --cluster-name $KUBE_NAME \
            --name userpool \
            --mode user \
            --node-count 2 \
            --node-taints "node.cilium.io/agent-not-ready=true:NoSchedule" \
            --no-wait


 az aks nodepool delete --resource-group $KUBE_GROUP --cluster-name $KUBE_NAME \
            --name "${nodepool_to_delete}"

helm repo add cilium https://helm.cilium.io/

helm upgrade cilium cilium/cilium --install --version 1.11.0 \
  --namespace kube-system \
  --set azure.enabled=true \
  --set azure.resourceGroup=$NODE_GROUP \
  --set azure.subscriptionID=$SUBSCRIPTION_ID \
  --set azure.tenantID=$TENANT_ID \
  --set azure.clientID=$SERVICE_PRINCIPAL_ID \
  --set azure.clientSecret=$SERVICE_PRINCIPAL_SECRET \
  --set tunnel=disabled \
  --set ipam.mode=azure \
  --set enableIPv4Masquerade=false \
  --set nodeinit.enabled=true

kubectl get pods --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,HOSTNETWORK:.spec.hostNetwork --no-headers=true | grep '<none>' | awk '{print "-n "$1" "$2}' | xargs -L 1 -r kubectl delete pod


kubectl create ns cilium-test

kubectl apply -n cilium-test -f https://raw.githubusercontent.com/cilium/cilium/v1.9/examples/kubernetes/connectivity-check/connectivity-check.yaml


kubectl get pods -n cilium-test


kubectl apply -f https://raw.githubusercontent.com/cilium/cilium/HEAD/examples/kubernetes/connectivity-check/connectivity-check.yaml



kubectl logs -l name=echo
kubectl logs -l name=probe
```

## Configure Hubble
https://github.com/cilium/hubble

```
export CILIUM_NAMESPACE=kube-system

helm upgrade cilium cilium/cilium --version 1.9.11 \
   --namespace $CILIUM_NAMESPACE \
   --reuse-values \
   --set hubble.listenAddress=":4244" \
   --set hubble.relay.enabled=true \
   --set hubble.ui.enabled=true

kubectl port-forward -n $CILIUM_NAMESPACE svc/hubble-ui --address 0.0.0.0 --address :: 12000:80

export HUBBLE_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/hubble/master/stable.txt)
curl -LO "https://github.com/cilium/hubble/releases/download/$HUBBLE_VERSION/hubble-darwin-amd64.tar.gz"
curl -LO "https://github.com/cilium/hubble/releases/download/$HUBBLE_VERSION/hubble-darwin-amd64.tar.gz.sha256sum"
shasum -a 256 -c hubble-darwin-amd64.tar.gz.sha256sum
tar zxf hubble-darwin-amd64.tar.gz

sudo mv hubble /usr/local/bin

kubectl port-forward -n $CILIUM_NAMESPACE svc/hubble-relay --address 0.0.0.0 --address :: 4245:80


hubble --server localhost:4245 status

hubble --server localhost:4245 observe

```