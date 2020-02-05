# Kubernetes ingress controller

Easy way via helm
https://docs.microsoft.com/en-us/azure/aks/ingress
https://github.com/helm/charts/tree/master/stable/nginx-ingress

## Internal Ip

Configur ingress variables to use internal assigned ip adress from a different subnet
```
INTERNALINGRESSIP="10.0.2.10"
INGRESSSUBNETNAME="InternalIngressSubnet"
```

 "annotations": {
        "service.beta.kubernetes.io/azure-load-balancer-internal": "true"
    }

helm install stable/nginx-ingress --name ingress-controller --namespace kube-system --set controller.service.enableHttps=false -f ingres-values.yaml
helm delete ingress-controller --purge

cat <<EOF | kubectl create -n nginx-demo -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: nginx-ingress
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - http:
      paths:
      - path: /
        backend:
          serviceName: nginx
          servicePort: 80
EOF

## External Ip, DNS and Certificate
https://docs.microsoft.com/en-us/azure/aks/ingress#install-an-ingress-controller

Create a public ip adress
```

az network public-ip create --resource-group MC_kub_ter_a_m_mesh11_mesh11_westeurope --name myAKSPublicIP --allocation-method static

az network public-ip list --resource-group MC_kubeaksvmss_dzkubes_westeurope* --query [0].ipAddress --output tsv

IP="1.1.1.1"
```
Use the assigned ip address in the helm chart

```
helm upgrade stable/nginx-ingress --install --name ingress-controller --namespace kube-system --set rbac.create=true --set controller.service.loadBalancerIP="$IP" --set controller.stats.enabled=true --set controller.replicaCount=2 --set controller.service.externalTrafficPolicy=Local

helm upgrade ingress-controller stable/nginx-ingress --install --namespace kube-system --set controller.stats.enabled=true --set controller.replicaCount=2 --set controller.service.externalTrafficPolicy=Local

helm install stable/nginx-ingress --name ingress-controller --namespace kube-system --set controller.service.externalTrafficPolicy=Local
helm upgrade quiet-echidna stable/nginx-ingress  --set controller.service.externalTrafficPolicy=Local

# dedicate dip
helm upgrade nginx-ingress stable/nginx-ingress  --set controller.service.externalTrafficPolicy=Local --set controller.replicaCount=2 --set controller.service.loadBalancerIP=104.46.49.182 --set rbac.create=true --namespace kube-system

# internal
helm upgrade nginx-ingress stable/nginx-ingress  --set controller.service.externalTrafficPolicy=Local --set controller.replicaCount=2 --set rbac.create=true --set controller.service.annotations="{service.beta.kubernetes.io/azure-load-balancer-internal:\\"true"} --namespace kube-system

helm upgrade --install nginx-ingress stable/nginx-ingress --set controller.service.externalTrafficPolicy=Local --set controller.replicaCount=2 --set controller.metrics.enabled=true --set controller.stats.enabled=true	--namespace ingress

helm upgrade --install nginx-ingress stable/nginx-ingress --set controller.service.externalTrafficPolicy=Local --set controller.replicaCount=2 --namespace ingress

KUBE_EDITOR="nano" kubectl edit svc/nginx-ingress-controller -n kube-system

service.beta.kubernetes.io/azure-load-balancer-internal: "true"

controller:
  service:
    loadBalancerIP: 10.240.0.42
    annotations:
      service.beta.kubernetes.io/azure-load-balancer-internal: "true"

     --set ingress.annotations={kubernetes.io/ingress.class:\\n\\nginx} config-service
--set alertmanager.ingress.annotations."alb\.ingress\.kubernetes\.io/scheme"=internet-facing

```

## DNSName to associate with public IP address
https://docs.microsoft.com/en-us/azure/aks/ingress#configure-a-dns-name

```
DNSNAME="dzapis"

PUBLICIPID=$(az network public-ip list --query "[?ipAddress!=null]|[?contains(ipAddress, '$IP')].[id]" --output tsv)


DNS=$DNSNAME.westeurope.cloudapp.azure.com

az network public-ip update --ids $PUBLICIPID --dns-name $DNSNAME
```

## Create dummy ingress for challenge
dzapis.westeurope.cloudapp.azure.com

```
kubectl run nginx --image nginx --port=80

kubectl expose deployment nginx --type=ClusterIP

cat <<EOF | kubectl apply -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: nginx-ingress
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - host: $DNS
    http:
      paths:
      - path: /
        backend:
          serviceName: nginx
          servicePort: 80
EOF

cat <<EOF | kubectl create -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: nginx-ingress
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  tls:
  - hosts:
    - $DNS
    secretName: hello-tls-secret
  rules:
  - host: $DNS
    http:
      paths:
      - path: /
        backend:
          serviceName: nginx
          servicePort: 80
EOF
```

launch dns
```
open http://$DNS
```

install demo app
```
helm repo add azure-samples https://azure-samples.github.io/helm-charts/
helm install azure-samples/aks-helloworld
helm install azure-samples/aks-helloworld --set title="AKS Ingress Demo" --set serviceName="ingress-demo"
```

## Install certmanager for letsencrypt suppot
https://docs.microsoft.com/en-us/azure/aks/ingress#install-cert-manager

install cert manager
```
helm install stable/cert-manager --name cert-issuer-manager --namespace kube-system --set ingressShim.defaultIssuerName=letsencrypt-prod --set ingressShim.defaultIssuerKind=ClusterIssuer
```

create cert manager cluster issuer for stage or prod
```
cat <<EOF | kubectl apply -f -
apiVersion: certmanager.k8s.io/v1alpha1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
  namespace: ingress-basic
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: $MY_USER_ID
    privateKeySecretRef:
      name: letsencrypt-prod
    http01: {}
EOF
```

staging

```
cat <<EOF | kubectl apply -f -
apiVersion: certmanager.k8s.io/v1alpha1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: $MY_USER_ID
    privateKeySecretRef:
      name: letsencrypt-prod
    http01: {}
EOF

```

create certificate

```

cat <<EOF | kubectl apply -f -
apiVersion: certmanager.k8s.io/v1alpha1
kind: Certificate
metadata:
  name: hello-tls-secret
spec:
  secretName: hello-tls-secret
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

you can now create the nginx-ingress
```
kubectl delete ingress nginx-ingress
```

create ingress

```

cat <<EOF | kubectl apply -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: hello-world-ingress
  namespace: ingress-basic
  annotations:
    kubernetes.io/ingress.class: nginx
    certmanager.k8s.io/cluster-issuer: letsencrypt-staging
    nginx.ingress.kubernetes.io/rewrite-target: /$1
spec:
  tls:
  - hosts:
    - dzapis.westeurope.cloudapp.azure.com
    secretName: tls-secret
  rules:
  - host: dzapis.westeurope.cloudapp.azure.com
    http:
      paths:
      - backend:
          serviceName: aks-helloworld
          servicePort: 80
        path: /(.*)
EOF
```

Cleanup
```
kubectl delete ingress hello-world-ingress
kubectl delete certificate hello-tls-secret
kubectl delete clusterissuer letsencrypt-staging
helm delete cert-issuer-manager --purge
```

## Ingress controller manually

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
