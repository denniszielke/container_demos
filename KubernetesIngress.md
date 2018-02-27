# Kubernetes ingress controller

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