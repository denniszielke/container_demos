# Network Policy on Kubernetes on Azure

Here are a couple of network policy samples: https://github.com/ahmetb/kubernetes-network-policy-recipes

The following options exist for AKS:

1. Deploying kube-router to AKS
```
kubectl apply -f  https://raw.githubusercontent.com/denniszielke/container_demos/master/networkpolicies/kube-router-firewall-daemonset-aks.yaml
```

2. Deploying azure npm to AKS (works only with azure-cni)
```
kubectl apply -f  https://github.com/Azure/acs-engine/blob/master/parts/k8s/addons/kubernetesmasteraddons-azure-npm-daemonset.yaml
```

> in order for dns to work you need to allow dns traffic on port 53 to 168.63.129.16

## Example: Locking down outgoing traffic except for a postgresql database in azure

1. create postgres db
```
PSQL_PASSWORD=$(openssl rand -base64 10)
az postgres server create --resource-group $KUBE_GROUP --name $KUBE_NAME  --location $LOCATION --admin-user myadmin --admin-password $PSQL_PASSWORD --sku-name GP_Gen4_2 --version 9.6
```

lock up details
```
az postgres server show --resource-group $KUBE_GROUP --name $KUBE_NAME
```

ping server to get ip in this case the ip comes from 191.237.232.0/22 range

2. activate service endpoint to join psql to existing kubernetes vnet
```
KUBE_AGENT_SUBNET_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$KUBE_GROUP/providers/Microsoft.Network/virtualNetworks/$KUBE_VNET_NAME/subnets/$KUBE_AGENT_SUBNET_NAME"
az postgres server vnet-rule create -g $KUBE_GROUP -s $KUBE_NAME -n psqlvnetrule --subnet $KUBE_AGENT_SUBNET_ID
```

3. create policy to allow only egress traffic to psql for all containers that have `run:pdemo` label

```
cat <<EOF | kubectl create -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: limit-deny-external-egress
spec:
  podSelector:
    matchLabels:
      run: pdemo
  policyTypes:
  - Egress
  egress:
  - ports:
    - port: 53
      protocol: UDP
    - port: 53
      protocol: TCP
    - port: 5432
      protocol: UDP
    - port: 5432
      protocol: TCP
    to:
    - ipBlock:
        cidr: 168.63.129.0/24
    - ipBlock:
        cidr: 191.237.232.0/22
EOF
```

4. create pod to test network policy

use postgres image to test postgres to verify that the connection works
```
cat <<EOF | kubectl create -f -
kind: Pod
apiVersion: v1
metadata:
  name: pclient
  labels:
    run: pdemo
spec:
  containers:
    - name: postgres
      image: postgres
EOF
```

log into the box
```
kubectl exec -ti runclient -- sh
```

log into psql 
```
psql --host=$KUBE_NAME.postgres.database.azure.com --username=myadmin@$KUBE_NAME --dbname=db --port=5432 
```

should work!

5. run a ubuntu image to see that normal internet does not
```
cat <<EOF | kubectl create -f -
kind: Pod
apiVersion: v1
metadata:
  name: runclient
  labels:
    run: pdemo
spec:
  containers:
    - name: ubuntu
      image: tutum/curl
      command: ["tail"]
      args: ["-f", "/dev/null"]
EOF
```

log into the box
```
kubectl exec -ti runclient -- sh
```

install dependencies for tracing + wget
```
sudo apt-get install --fix-missing  
sudo apt-get update && apt-get install traceroute 
sudo apt-get install inetutils-traceroute
sudo apt install wget

traceroute -T -n $KUBE_NAME.postgres.database.azure.com

wget --timeout 1 -O- http://www.example.com

https://github.com/jamesbrink/docker-postgres
```

should not work!