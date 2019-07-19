# Install istio
https://istio.io/docs/setup/kubernetes/quick-start/#download-and-prepare-for-the-installation

curl -L https://git.io/getLatestIstio | sh -

export PATH="$PATH:/Users/dennis/istio-0.8.0/bin"
export PATH="$PATH:/Users/dennis/lib/istio-1.0.0/bin"

https://istio.io/docs/setup/kubernetes/helm-install/


helm template install/kubernetes/helm/istio --name istio --namespace istio-system > $HOME/istio.yaml

helm template install/kubernetes/helm/istio --name istio --namespace istio-system --set sidecarInjectorWebhook.enabled=false > $HOME/istio.yaml


kubectl -n istio-system port-forward $(kubectl -n istio-system get pod -l app=grafana -o jsonpath='{.items[0].metadata.name}') 3000:3000 &

kubectl label namespace calculator istio-injection=enabled
kubectl label namespace calculator istio-injection=disabled


## Install grafana dashboard
https://istio.io/docs/tasks/telemetry/using-istio-dashboard/


kubectl -n default port-forward $(kubectl -n default get pod -l app=vistio-api -o jsonpath='{.items[0].metadata.name}') 9091:9091 &

http://localhost:9091/graph

kubectl -n default port-forward $(kubectl -n default get pod -l app=vistio-web -o jsonpath='{.items[0].metadata.name}') 8080:8080 &

http://localhost:8080

kubectl -n istio-system port-forward $(kubectl -n istio-system get \
  pod -l app=grafana -o jsonpath='{.items[0].metadata.name}') 3000:3000 &

kubectl apply --record -f <(istioctl kube-inject -f ./full-deply.yaml)

cat <<EOF | istioctl create -f -
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: front-virtual-service
spec:
  hosts:
  - "*"
  gateways:
  - front-gateway
  http:
  - match:
    - uri:
        prefix: /app/front
    route:
    - destination:
        host: calc-frontend-svc
EOF

cat <<EOF | istioctl create -f -
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: reviews
spec:
  hosts:
    - reviews
  http:
  - route:
    - destination:
        host: reviews
        subset: v1
      weight: 75
    - destination:
        host: reviews
        subset: v2
      weight: 25
EOF

cat <<EOF | istioctl create -f -
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: front-gateway
spec:
  selector:
    istio: ingressgateway # use istio default controller
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*"
EOF

cat <<EOF | istioctl create -f -
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: delay-calc
spec:
  hosts:
  - calc-backend-svc
  http:
  - fault:
      delay:
        fixedDelay: 7s
        percent: 100
    match:
    - headers:
        number:
          regex: ^(.*?)?(.*7.*)(.*)?$
    route:
    - destination:
        host: calc-backend-svc
  - route:
    - destination:
        host: calc-backend-svc
EOF


kubectl apply -f https://raw.githubusercontent.com/CSA-OCP-GER/unicorn/master/hints/yaml/challenge-istio/base-sample-app.yaml

helm install install/kubernetes/helm/istio --name istio --namespace istio-system --values install/kubernetes/helm/istio/values.yaml

kubectl get po -n istio-system

kubectl port-forward grafana-749c78bcc5-mrw8f 3000:3000 -n istio-system


KIALI_USERNAME=$(read '?Kiali Username: ' uval && echo -n $uval | base64)
KIALI_PASSPHRASE=$(read -s "?Kiali Passphrase: " pval && echo -n $pval | base64)
NAMESPACE=istio-system

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: kiali
  namespace: $NAMESPACE
  labels:
    app: kiali
type: Opaque
data:
  username: $KIALI_USERNAME
  passphrase: $KIALI_PASSPHRASE
EOF

kubectl port-forward kiali-68677d47d7-hdpfq 20001:20001 -n istio-system

kubectl --namespace istio-system port-forward $(kubectl get pod --namespace istio-system -l app=kiali -o template --template "{{(index .items 0).metadata.name}}") 20001:20001

kubectl apply -f https://raw.githubusercontent.com/CSA-OCP-GER/unicorn/master/hints/yaml/challenge-istio/request-routing/c2-ingress-rr.yaml

kubectl delete -f https://raw.githubusercontent.com/CSA-OCP-GER/unicorn/master/hints/yaml/challenge-istio/faultinjection/c2-ingress-rr-faulty-delay.yaml

kubectl apply -f https://raw.githubusercontent.com/CSA-OCP-GER/unicorn/master/hints/yaml/challenge-istio/faultinjection/c2-error-frontend.yaml

kubectl apply -f https://raw.githubusercontent.com/CSA-OCP-GER/unicorn/master/hints/yaml/challenge-istio/faultinjection/c2-ingress-rr-faulty-error.yaml

kubectl delete -f https://raw.githubusercontent.com/CSA-OCP-GER/unicorn/master/hints/yaml/challenge-istio/faultinjection/c2-ingress-rr-faulty-error.yaml