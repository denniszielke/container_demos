# install
https://kubecost.com/install

```
kubectl create namespace kubecost
helm repo add kubecost https://kubecost.github.io/cost-analyzer/
helm install kubecost kubecost/cost-analyzer --namespace kubecost --set kubecostToken="YXNkZmFzZGZAc2FmZC5kZQ==xm343yadf98"


kubectl port-forward --namespace kubecost deployment/kubecost-cost-analyzer 9090 


helm repo add stable https://kubernetes-charts.storage.googleapis.com
helm install kubecost-ingress stable/nginx-ingress -n kubecost
export IGCIP=$(kubectl get svc -o jsonpath="{.status.loadBalancer.ingress[0].ip}" kubecost-ingress-nginx-ingress-controller -n kubecost)

htpasswd -c auth kubecost-admin

kubectl create secret generic \
    kubecost-auth \
    --from-file auth \
    -n kubecost

echo "
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  annotations:
    nginx.ingress.kubernetes.io/auth-realm: Authentication Required - ok
    nginx.ingress.kubernetes.io/auth-secret: kubecost-auth
    nginx.ingress.kubernetes.io/auth-type: basic
  labels:
    app: cost-analyzer
  name: kubecost-cost-analyzer
  namespace: kubecost
spec:
  rules:
  - host: $IGCIP.xip.io
    http:
      paths:
      - backend:
          serviceName: kubecost-cost-analyzer
          servicePort: 9090
        path: /
" | kubectl apply -f -

echo "
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  labels:
    app: cost-analyzer
  name: kubecost-cost-analyzer
  namespace: kubecost
spec:
  rules:
  - host: $IGCIP.xip.io
    http:
      paths:
      - backend:
          serviceName: kubecost-cost-analyzer
          servicePort: 9090
        path: /
" | kubectl apply -f -

```
