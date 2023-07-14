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

## DNS Policy

```

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: centos
  labels:
    org: secured
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

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: centos1
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


httpbin.org/get
ipinfo.io/ip

cat <<EOF | kubectl apply -f -
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: "fqdn"
spec:
  endpointSelector: {}
  ingress:
    - fromEndpoints:
        - matchLabels:
            org: secured
  egress:
  - toFQDNs:
    - matchName: "ipinfo.io"
  - toEndpoints:
    - matchLabels:
        "k8s:io.kubernetes.pod.namespace": kube-system
        "k8s:k8s-app": kube-dns
    toPorts:
    - ports:
      - port: "53"
        protocol: ANY
      rules:
        dns:
        - matchPattern: "*"
EOF
```

## Layer 7 visibility

```
kubectl annotate pod foo -n bar policy.cilium.io/proxy-visibility="<Egress/53/UDP/DNS>,<Egress/80/TCP/HTTP>"


kubectl annotate pod calculator-multicalculator-backend-b7d75c597-5vvwg -n calculator policy.cilium.io/proxy-visibility="<Egress/53/UDP/DNS>,<Egress/80/TCP/HTTP>"
kubectl annotate pod calculator-multicalculator-backend-b7d75c597-dzzhv  -n calculator policy.cilium.io/proxy-visibility="<Egress/53/UDP/DNS>,<Egress/80/TCP/HTTP>"
kubectl annotate pod calculator-multicalculator-backend-b7d75c597-frbj4 -n calculator policy.cilium.io/proxy-visibility="<Egress/53/UDP/DNS>,<Egress/80/TCP/HTTP>"
kubectl annotate pod calculator-multicalculator-backend-b7d75c597-qqfp6 -n calculator policy.cilium.io/proxy-visibility="<Egress/53/UDP/DNS>,<Egress/80/TCP/HTTP>"
kubectl annotate pod calculator-multicalculator-frontend-86c8866b47-6ftqz -n calculator policy.cilium.io/proxy-visibility="<Egress/53/UDP/DNS>,<Egress/80/TCP/HTTP>"
kubectl annotate pod calculator-multicalculator-frontend-86c8866b47-6zhhj -n calculator policy.cilium.io/proxy-visibility="<Egress/53/UDP/DNS>,<Egress/80/TCP/HTTP>"
kubectl annotate pod calculator-multicalculator-frontend-86c8866b47-dm2w2 -n calculator policy.cilium.io/proxy-visibility="<Egress/53/UDP/DNS>,<Egress/80/TCP/HTTP>"
kubectl annotate pod calculator-multicalculator-frontend-86c8866b47-fvmmw -n calculator policy.cilium.io/proxy-visibility="<Egress/53/UDP/DNS>,<Egress/80/TCP/HTTP>"


```

## Enterprise

```
az k8s-extension update -c $CLUSTER_NAME -t managedClusters -g $RG_NAME -n cilium --configuration-settings namespace=kube-system hubble.enabled=true

az k8s-extension update -c $CLUSTER_NAME -t managedClusters -g $RG_NAME -n cilium --configuration-settings hubble.relay.enabled=true

az k8s-extension show --cluster-name $CLUSTER_NAME --resource-group $RG_NAME --cluster-type managedClusters -n cilium

kubectl --namespace=kube-system exec -i -t ds/cilium  -- cilium version

# cee = cilium enterprise edition


cilium status

kubectl -n kube-system exec ds/cilium -- cilium-health status

kubectl describe deploy cilium-operator -n kube-system | grep "Image:"

 

# Temporary work around to install Hubble UI OSS version in Enterprise version (this will be available soon)

helm install --namespace kube-system cilium cilium/cilium --version 1.13.4 -f hubble-standalone-values.yaml

```

hubble stand alone values

````

agent: false
operator:
  enabled: false
cni:
  install: false
hubble:
  enabled: false
  relay:
    # set this to false as Hubble relay is already installed
    enabled: false
    tls:
      server:
        # set this to true if tls is enabled on Hubble relay server side
        enabled: false
  ui:
    # enable Hubble UI
    enabled: true
    standalone:
      # enable Hubble UI standalone deployment
      enabled: true
```

cilium hubble port-forward

# In another terminal

cilium hubble ui

ℹ️  Opening "http://localhost:12000" in your browser.