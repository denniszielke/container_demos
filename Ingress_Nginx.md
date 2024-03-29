# Nginx
https://github.com/kubernetes/ingress-nginx/blob/master/docs/user-guide/nginx-configuration/annotations.md
https://github.com/kubernetes/ingress-nginx/blob/master/charts/ingress-nginx/values.yaml

## Install nginx
```

NODE_GROUP=$(az aks show --resource-group $KUBE_GROUP --name $KUBE_NAME --query nodeResourceGroup -o tsv)

IP_NAME=k$KUBE_NAME

az network public-ip create --resource-group $NODE_GROUP --name $IP_NAME --sku Standard --allocation-method static --dns-name dznginx

IP=$(az network public-ip show --resource-group $NODE_GROUP --name $IP_NAME --query ipAddress --output tsv)
DNS=$(az network public-ip show --resource-group $NODE_GROUP --name $IP_NAME --query dnsSettings.fqdn --output tsv)

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm search repo nginx-ingress

AKS_CONTROLLER_CLIENT_ID="$(az identity list -g $KUBE_GROUP --query "[?contains(name, '$KUBE_NAME-ctl-id')].clientId" -o tsv)"
AKS_CONTROLLER_RESOURCE_ID="$(az identity list -g $KUBE_GROUP --query "[?contains(name, '$KUBE_NAME-clt-id')].id" -o tsv)"

IP_ID=$(az network public-ip list -g $KUBE_GROUP --query "[?contains(name, 'dznginx')].id" -o tsv)
if [ "$IP_ID" == "" ]; then
    echo "creating ingress ip dznginx"
    az network public-ip create -g $KUBE_GROUP -n dznginx --sku STANDARD --dns-name k$KUBE_NAME -o none
    IP_ID=$(az network public-ip show -g $KUBE_GROUP -n dznginx -o tsv --query id)
    IP=$(az network public-ip show -g $KUBE_GROUP -n dznginx -o tsv --query ipAddress)
    DNS=$(az network public-ip show -g $KUBE_GROUP -n dznginx -o tsv --query dnsSettings.fqdn)
    echo "created ip $IP_ID with $IP on $DNS"
    az role assignment create --role "Contributor" --assignee $AKS_CONTROLLER_CLIENT_ID --scope $IP_ID -o none
else
    IP=$(az network public-ip show -g $KUBE_GROUP -n dznginx -o tsv --query ipAddress)
    DNS=$(az network public-ip show -g $KUBE_GROUP -n dznginx -o tsv --query dnsSettings.fqdn)
    echo "AKS $AKS_ID already exists with $IP on $DNS"
fi


kubectl create ns nginx

helm upgrade ingress-nginx ingress-nginx/ingress-nginx --install \
    --namespace ingress --create-namespace\
    --set controller.replicaCount=2 \
    --set controller.metrics.enabled=true \
    --set controller.service.loadBalancerIP="$IP" \
    --set defaultBackend.enabled=true \
    --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz  \
    --set controller.service.externalTrafficPolicy=Local \
    --set-string controller.tolerations.app=game \
    --set-string controller.nodeSelector.ingress=true \
    --set-string controller.service.annotations.'service\.beta\.kubernetes\.io/azure-load-balancer-resource-group'="$KUBE_GROUP" \
    --set-string controller.service.annotations.'service\.beta\.kubernetes\.io/azure-pip-name'="dznginx" 

-f consul-helm/values.yaml

helm upgrade my-ingress-controller nginx/nginx-ingress --install --set controller.stats.enabled=true --set controller.replicaCount=2 --set controller.service.externalTrafficPolicy=Local --namespace=nginx

helm upgrade my-ingress-controller nginx/nginx-ingress --install --set controller.service.loadBalancerIP="$IP" --set controller.stats.enabled=true --set controller.replicaCount=2 --set controller.service.externalTrafficPolicy=Local --namespace=nginx

helm install nginx nginx/nginx-ingress \
    --namespace nginx --set controller.service.loadBalancerIP="$IP" --set controller.service.externalTrafficPolicy=Local \
    --set controller.replicaCount=2 \
    --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux \
    --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux

helm upgrade my-ingress-controller nginx/nginx-ingress --install --set controller.stats.enabled=true --set controller.replicaCount=2 --set controller.service.externalTrafficPolicy=Local --namespace=nginx

```

## Metrics

```
InsightsMetrics
| extend tags=parse_json(Tags)
| where tostring(tags.controller_class) == "nginx" 

Calculate requests per minute:


InsightsMetrics
| where Name == "nginx_ingress_controller_nginx_process_connections_total" 
| summarize Val=any(Val) by TimeGenerated=bin(TimeGenerated, 1m)
| sort by TimeGenerated asc 
| extend RequestsPerMinute = Val - prev(Val) 
| sort by TimeGenerated desc 

bar chart


 InsightsMetrics
| where Name == "nginx_ingress_controller_nginx_process_connections_total" 
| summarize Val=any(Val) by TimeGenerated=bin(TimeGenerated, 1m)
| sort by TimeGenerated asc 
| project RequestsPerMinute = Val - prev(Val), TimeGenerated 
| render barchart  

InsightsMetrics
| extend tags=parse_json(Tags)
| where Name == "nginx_connections_accepted"

InsightsMetrics
| where Name == "nginx_http_requests_total" 
| summarize Val=any(Val) by TimeGenerated=bin(TimeGenerated, 1m)
| sort by TimeGenerated asc 
| extend RequestsPerMinute = Val - prev(Val) 
| sort by TimeGenerated desc 

 InsightsMetrics
| where Name == "nginx_http_requests_total" 
| summarize Val=any(Val) by TimeGenerated=bin(TimeGenerated, 1m)
| sort by TimeGenerated asc 
| project RequestsPerMinute = Val - prev(Val), TimeGenerated 
| render barchart  

```

## demo app

```

kubectl create deployment hello-echo --image=gcr.io/kuar-demo/kuard-amd64:1 --port=8080

kubectl expose deployment echoserver --type=LoadBalancer --port=8080 --namespace=ingress-basic

cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: http-dummy-logger-app
  namespace: default
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/enable-modsecurity: "true"
    nginx.ingress.kubernetes.io/modsecurity-snippet: |
      SecRuleEngine On
      SecRule &REQUEST_HEADERS:X-Azure-FDID \"@eq 0\"  \"log,deny,id:106,status:403,msg:\'Front Door ID not present\'\"
      SecRule REQUEST_HEADERS:X-Azure-FDID \"@rx ^(?!4bc12b25-fa53-43c3-ab49-1ec3950b5290).*$\"  \"log,deny,id:107,status:403,msg:\'Wrong Front Door ID\'\"
spec:  
  ingressClassName: nginx
  rules:
  - host: dznginx.eastus.cloudapp.azure.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: dummy-logger
            port:
              number: 80
EOF

curl -H "X-Azure-FDID:4bc12b25-fa53-43c3-ab49-1ec3950b5290" dznginx.eastus.cloudapp.azure.com

apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: kuard
  annotations:
    kubernetes.io/ingress.class: "nginx"    
    #cert-manager.io/issuer: "letsencrypt-staging"
spec:
  tls:
  - hosts:
    - example.example.com
    secretName: quickstart-example-tls
  rules:
  - host: example.example.com
    http:
      paths:
      - path: /
        backend:
          serviceName: kuard
          servicePort: 80

```
## Lets encrypt

```
kubectl label namespace nginx cert-manager.io/disable-validation=true


helm repo add jetstack https://charts.jetstack.io

helm repo update

helm upgrade \
  cert-manager --install \
  --namespace nginx \
  --version v1.3.1 \
  --set installCRDs=true \
  --set nodeSelector."beta\.kubernetes\.io/os"=linux \
  jetstack/cert-manager

```
## Non HTTP Ingress

https://www.nginx.com/blog/announcing-nginx-ingress-controller-for-kubernetes-release-1-7-0/
https://docs.nginx.com/nginx-ingress-controller/configuration/global-configuration/globalconfiguration-resource/

```
apiVersion: k8s.nginx.org/v1alpha1
kind: GlobalConfiguration 
metadata:
  name: nginx-configuration
  namespace: nginx-ingress
spec:
  listeners:
  - name: dns-udp
    port: 5353
    protocol: UDP
  - name: dns-tcp
    port: 5353
    protocol: TCP


apiVersion: k8s.nginx.org/v1alpha1
kind: TransportServer
metadata:
  name: dns-tcp
spec:
  listener:
    name: dns-tcp 
    protocol: TCP
  upstreams:
  - name: dns-app
    service: coredns
    port: 5353
  action:
    pass: dns-app

apiVersion: k8s.nginx.org/v1alpha1
kind: TransportServer
metadata:
  name: secure-app
spec:
  listener:
    name: tls-passthrough
    protocol: TLS_PASSTHROUGH
  host: app.example.com
  upstreams:
    - name: secure-app
      service: secure-app
      port: 8443
  action:
    pass: secure-app

```
    https://github.com/nginxinc/kubernetes-ingress/tree/v1.7.0-rc1/examples-of-custom-resources/basic-tcp-udp

```
docker run -p 8080:8080 hashicorp/http-echo -listen=:8080 -text="hello world"
```