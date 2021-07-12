# Nginx
https://github.com/kubernetes/ingress-nginx/blob/master/docs/user-guide/nginx-configuration/annotations.md
https://github.com/kubernetes/ingress-nginx/blob/master/charts/ingress-nginx/values.yaml

## Install nginx
```

NODE_GROUP=$(az aks show --resource-group $KUBE_GROUP --name $KUBE_NAME --query nodeResourceGroup -o tsv)

IP_NAME=nginx-ingress-pip

az network public-ip create --resource-group $NODE_GROUP --name $IP_NAME --sku Standard --allocation-method static --dns-name dznginx

IP=$(az network public-ip show --resource-group $NODE_GROUP --name $IP_NAME --query ipAddress --output tsv)
DNS=$(az network public-ip show --resource-group $NODE_GROUP --name $IP_NAME --query dnsSettings.fqdn --output tsv)

helm repo add nginx https://helm.nginx.com/stable
helm repo update
helm search repo nginx-ingress


kubectl create ns nginx

helm upgrade my-ingress-controller nginx/nginx-ingress --install --set controller.stats.enabled=true --set controller.replicaCount=2 --set controller.service.externalTrafficPolicy=Local --namespace=nginx

helm upgrade my-ingress-controller nginx/nginx-ingress --install --set controller.service.loadBalancerIP="$IP" --set controller.stats.enabled=true --set controller.replicaCount=2 --set controller.service.externalTrafficPolicy=Local --namespace=nginx

helm install nginx nginx/nginx-ingress \
    --namespace nginx --set controller.service.loadBalancerIP="$IP" --set controller.service.externalTrafficPolicy=Local \
    --set controller.replicaCount=2 \
    --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux \
    --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux

helm upgrade my-ingress-controller nginx/nginx-ingress --install --set controller.stats.enabled=true --set controller.replicaCount=2 --set controller.service.externalTrafficPolicy=Local --namespace=nginx

```

## demo app

```

kubectl create deployment hello-echo --image=gcr.io/kuar-demo/kuard-amd64:1 --port=8080

kubectl expose deployment echoserver --type=LoadBalancer --port=8080 --namespace=ingress-basic

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