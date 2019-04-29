
kubectl apply -f https://raw.githubusercontent.com/containous/traefik/v1.7/examples/k8s/traefik-rbac.yaml
https://github.com/thomseddon/traefik-forward-auth

helm install stable/traefik --name mytraefik --namespace kube-system --set dashboard.enabled=true,dashboard.domain=dashboard.localhost,rbac.enabled=true,kubernetes.namespaces=default

helm upgrade mytraefik stable/traefik --namespace kube-system --set dashboard.enabled=true,dashboard.domain=dashboard.localhost,rbac.enabled=true

kubectl -n kube-system port-forward $(kubectl -nkube-system get pod -l app=traefik -o jsonpath='{.items[0].metadata.name}') 8080:8080

annotations:
https://docs.traefik.io/configuration/backends/kubernetes/#general-annotations


kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/logging/dummy-logger/depl-logger.yaml
kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/logging/dummy-logger/svc-cluster-logger.yaml
kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/logging/dummy-logger/pod-logger.yaml

kubectl get -n colors deploy -o yaml \
  | linkerd inject - \
  | kubectl apply -f -

DNS=13.95.69.233.xip.io

cat <<EOF | kubectl apply -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: dummy-logger
  annotations:
    kubernetes.io/ingress.class: traefik
    ingress.kubernetes.io/whitelist-x-forwarded-for: "true"
    traefik.ingress.kubernetes.io/redirect-permanent: "true"
    traefik.ingress.kubernetes.io/preserve-host: "true"
    traefik.ingress.kubernetes.io/rewrite-target: /
    traefik.ingress.kubernetes.io/rate-limit: |
      extractorfunc: client.ip
      rateset:
        rateset1:
          period: 3s
          average: 3
          burst: 5
spec:
  rules:
  - host: $DNS
    http:
      paths:
      - path: /logger
        backend:
          serviceName: dummy-logger-cluster
          servicePort: 80
EOF

for i in `seq 1 10000`; do time curl -s http://$DNS > /dev/null; done

for i in `seq 1 10000`; do time curl -s http://13.95.69.233.xip.io/color; done
DNS=13.95.69.233.xip.io/color


cat <<EOF | kubectl apply -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  annotations:
    kubernetes.io/ingress.class: traefik
    traefik.ingress.kubernetes.io/rewrite-target: /
    traefik.ingress.kubernetes.io/service-weights: |
      color-blue-svc: 90%
      color-green-svc: 10%
  name: colors
  namespace: colors
spec:
  rules:
  - host: 13.95.69.233.xip.io
    http:
      paths:
      - backend:
          serviceName: color-blue-svc
          servicePort: 80
        path: /color
      - backend:
          serviceName: color-green-svc
          servicePort: 80
        path: /color
EOF