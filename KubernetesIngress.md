# Kubernetes ingress controller

Easy way via helm
https://docs.microsoft.com/en-us/azure/aks/ingress

```
helm install stable/nginx-ingress --namespace kube-system --set rbac.create=true
IP="51.145.155.210"

# Name to associate with public IP address
DNSNAME="demo-aks-ingress"

DNS=

helm upgrade 
helm install stable/cert-manager --set ingressShim.defaultIssuerName=letsencrypt-prod --set ingressShim.defaultIssuerKind=ClusterIssuer


```


create cert manager cluster issuer
```
cat <<EOF | kubectl create -f -
apiVersion: certmanager.k8s.io/v1alpha1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: $MY_USER_ID
    privateKeySecretRef:
      name: letsencrypt-prod
    http01: {}
EOF
```

create certificate

```
cat <<EOF | kubectl create -f -
apiVersion: certmanager.k8s.io/v1alpha1
kind: Certificate
metadata:
  name: tls-secret
spec:
  secretName: tls-secret
  dnsNames:
  - $DNS
  acme:
    config:
    - http01:
        ingressClass: nginx
      domains:
      - $DNS
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
EOF
```

create ingress

```
cat <<EOF | kubectl create -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: hello-world-ingress
  annotations:
    kubernetes.io/ingress.class: nginx
    certmanager.k8s.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  tls:
  - hosts:
    - $DNS
    secretName: tls-secret
  rules:
  - host: $DNS
    http:
      paths:
      - path: /
        backend:
          serviceName: aks-helloworld
          servicePort: 80
      - path: /hello-world-two
        backend:
          serviceName: ingress-demo
          servicePort: 80
EOF
```

## Ingress controller

1. Provision default backend
```
kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/services/default-backend.yaml
```
2. Create ingress service
```
kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/services/default-svc.yaml
```
3. Create ingress service
```
kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/services/ingress-svc.yaml
```
4. Get ingress public ip adress to that service
```
kubectl get svc
```
5. Create ingress controller
```
kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/services/ingress-ctl.yaml
```
6. Deploy ingress
```
kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/services/color-ingress.yaml
```

Test it
```
curl -H 'Host:mysite.com' [ALB_IP]
```

## Ingress & SSL Termination
https://kubernetes.io/docs/concepts/services-networking/ingress/
https://dgkanatsios.com/2017/07/07/using-ssl-for-a-service-hosted-on-a-kubernetes-cluster/

https://blogs.technet.microsoft.com/livedevopsinjapan/2017/02/28/configure-nginx-ingress-controller-for-tls-termination-on-kubernetes-on-azure-2/
https://daemonza.github.io/2017/02/13/kubernetes-nginx-ingress-controller/

```
git clone https://github.com/kubernetes/ingress.git
cd ingress/examples/deployment/nginx
kubectl apply -f default-backend.yaml
kubectl -n kube-system get po
kubectl apply -f nginx-ingress-controller.yaml
kubectl -n kube-system get po
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=nginxsvc/O=nginxsvc"
kubectl create secret tls tls-secret --key tls.key --cert tls.crt
kubectl create -f http-svc.yaml
nano http-svc.yaml
kubectl create -f http-svc.yaml
kubectl get service
nano nginx-tls-ingress.yaml
kubectl create -f nginx-tls-ingress.yaml
rm nginx-tls-ingress.yaml
nano nginx-tls-ingress.yaml
kubectl create -f nginx-tls-ingress.yaml
kubectl get rs --namespace kube-system
kubectl expose rs nginx-ingress-controller-2781903634 --port=443 --target-port=443 --name=nginx-ingress-ssl --type=LoadBalancer --namespace kube-system
kubectl get services --namespace kube-system -w
```
