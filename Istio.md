# Install istio
https://istio.io/latest/docs/setup/getting-started/#download
```
curl -L https://git.io/getLatestIstio | sh -

export PATH="$PATH:/Users/dennis/lib/istio-1.8.0/bin"

https://istio.io/docs/setup/kubernetes/helm-install/


helm template install/kubernetes/helm/istio --name istio --namespace istio-system > $HOME/istio.yaml

helm template install/kubernetes/helm/istio --name istio --namespace istio-system --set sidecarInjectorWebhook.enabled=false > $HOME/istio.yaml


kubectl -n istio-system port-forward $(kubectl -n istio-system get pod -l app=grafana -o jsonpath='{.items[0].metadata.name}') 3000:3000 &

kubectl label namespace default istio-injection=enabled
kubectl label namespace calculator istio-injection=disabled


kubernetes.azure.com/mode=system

kubectl patch deployment istio-egressgateway -n istio-system -p \
  '{"spec":{"template":{"spec":{"nodeSelector":[{"kubernetes.azure.com/mode":"system"}]}}}}'
```
## Install grafana dashboard
https://istio.io/docs/tasks/telemetry/using-istio-dashboard/

```
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
```

## Istio 1.4.3
```
mkdir istio-1.4.3
ISTIO_VERSION=1.4.3
cd istio-1.4.3
curl -sL "https://github.com/istio/istio/releases/download/$ISTIO_VERSION/istio-$ISTIO_VERSION-osx.tar.gz" | tar xz\n

GRAFANA_USERNAME=$(echo -n "grafana" | base64)
GRAFANA_PASSPHRASE=$(echo -n "REPLACE_WITH_YOUR_SECURE_PASSWORD" | base64)

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: grafana
  namespace: istio-system
  labels:
    app: grafana
type: Opaque
data:
  username: $GRAFANA_USERNAME
  passphrase: $GRAFANA_PASSPHRASE
EOF

KIALI_USERNAME=$(echo -n "kiali" | base64)
KIALI_PASSPHRASE=$(echo -n "REPLACE_WITH_YOUR_SECURE_PASSWORD" | base64)

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: kiali
  namespace: istio-system
  labels:
    app: kiali
type: Opaque
data:
  username: $KIALI_USERNAME
  passphrase: $KIALI_PASSPHRASE
EOF

cd istio-$ISTIO_VERSION\nsudo cp ./bin/istioctl /usr/local/bin/istioctl\nsudo chmod +x /usr/local/bin/istioctl

helm repo add istio.io https://storage.googleapis.com/istio-release/releases/$ISTIO_VERSION/charts/\nhelm repo update

install crds
helm upgrade istio-init istio.io/istio-init --install --namespace istio-system

check for crds
kubectl get crds | grep 'istio.io' | wc -l

install istio
helm upgrade istio istio.io/istio --install --namespace istio-system --version $ISTIO_VERSION \
  --set global.controlPlaneSecurityEnabled=true \
  --set global.mtls.enabled=true \
  --set grafana.enabled=true --set grafana.security.enabled=true \
  --set tracing.enabled=true \
  --set kiali.enabled=true \
  --set global.defaultNodeSelector."beta\.kubernetes\.io/os"=linux

add injection
kubectl label namespace default istio-injection=enabled

check
kubectl get namespace -L istio-injection
kubectl get svc --namespace istio-system --output wide

https://jimmysong.io/en/posts/understanding-how-envoy-sidecar-intercept-and-route-traffic-in-istio-service-mesh/

https://istio.io/docs/examples/bookinfo/

deploy sample app
kubectl apply -f samples/bookinfo/platform/kube/bookinfo.yaml

curl productpage
kubectl exec -it $(kubectl get pod -l app=ratings -o jsonpath='{.items[0].metadata.name}') -c ratings -- curl productpage:9080/productpage | grep -o "<title>.*</title>"

<title>Simple Bookstore App</title>

kubectl apply -f samples/bookinfo/networking/bookinfo-gateway.yaml

kubectl get svc istio-ingressgateway -n istio-system

export INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')
export SECURE_INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="https")].port}')
export GATEWAY_URL=$INGRESS_HOST:$INGRESS_PORT

curl -s http://${GATEWAY_URL}/productpage | grep -o "<title>.*</title>"

set destination rules

kubectl apply -f samples/bookinfo/networking/destination-rule-all.yaml
```

## Egress gateway
```
meshConfig.outboundTrafficPolicy.mode 

istioctl install <flags-you-used-to-install-Istio> \
                   --set meshConfig.outboundTrafficPolicy.mode=REGISTRY_ONLY

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: centos
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

[root@centos /]# curl app.azuredns.com:8080/ip
{"realip":"172.16.0.180","remoteaddr":"172.16.0.180","remoteip":"172.16.0.180"}

app.azuredns.com:8080/ip

kubectl delete serviceentry azuredns
kubectl delete gateway istio-egressgateway
kubectl delete virtualservice direct-cnn-through-egress-gateway
kubectl delete destinationrule egressgateway-for-cnn

kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: ServiceEntry
metadata:
  name: azuredns
spec:
  hosts:
  - app.azuredns.com
  ports:
  - number: 80
    name: http
    protocol: HTTP
  resolution: DNS
EOF

kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: istio-egressgateway
spec:
  selector:
    istio: egressgateway
  servers:
  - port:
      number: 8080
      name: http
      protocol: HTTP
    hosts:
    - app.azuredns.com
---
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: egressgateway-for-cnn
spec:
  host: istio-egressgateway.istio-system.svc.cluster.local
  subsets:
  - name: azuredns
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: direct-cnn-through-egress-gateway
spec:
  hosts:
  - app.azuredns.com
  gateways:
  - mesh
  - istio-egressgateway
  http:
  - match:
    - gateways:
      - mesh
    route:
    - destination:
        host: istio-egressgateway.istio-system.svc.cluster.local
        subset: azuredns
        port:
          number: 8080
  - match:
    - gateways:
      - istio-egressgateway
    route:
    - destination:
        host: app.azuredns.com
        port:
          number: 8080
      weight: 100
EOF


kubectl apply -f - <<EOF
kind: Service
apiVersion: v1
metadata:
  name: my-httpbin
spec:
  type: ExternalName
  externalName: httpbin.org
  ports:
  - name: http
    protocol: TCP
    port: 80
EOF

kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: my-httpbin
spec:
  host: my-httpbin.default.svc.cluster.local
  trafficPolicy:
    tls:
      mode: DISABLE
EOF


kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: istio-egressgateway
spec:
  selector:
    istio: egressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - app.azuredns.com
---
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: egressgateway-for-cnn
spec:
  host: istio-egressgateway.istio-system.svc.cluster.local
  subsets:
  - name: azuredns
EOF


kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: direct-cnn-through-egress-gateway
spec:
  hosts:
  - app.azuredns.com
  gateways:
  - istio-egressgateway
  - mesh
  http:
  - match:
    - gateways:
      - mesh
      port: 80
    route:
    - destination:
        host: istio-egressgateway.istio-system.svc.cluster.local
        subset: azuredns
        port:
          number: 80
      weight: 100
  - match:
    - gateways:
      - istio-egressgateway
      port: 80
    route:
    - destination:
        host: app.azuredns.com
        port:
          number: 80
      weight: 100
EOF

kubectl logs -l istio=egressgateway -c istio-proxy -n istio-system | tail
```
➜  ~ (⎈ |dzvnets:default) kubectl exec -ti centos -- /bin/bash
Defaulting container name to centos.
Use 'kubectl describe pod/centos -n default' to see all of the containers in this pod.
[root@centos /]# curl app.azuredns.com/ip
{"realip":"10.0.5.35","remoteaddr":"10.0.5.35","remoteip":"10.0.5.35"}
[root@centos /]# exit
exit
➜  ~ (⎈ |dzvnets:default) kubectl logs -l istio=egressgateway -c istio-proxy -n istio-system | tail
2020-11-23T17:15:54.429430Z	info	sds	Skipping waiting for gateway secret
2020-11-23T17:15:54.429461Z	info	cache	Loaded root cert from certificate ROOTCA
2020-11-23T17:15:54.429698Z	info	sds	resource:ROOTCA pushed root cert to proxy
2020-11-23T17:15:56.021434Z	info	Envoy proxy is ready
[2020-11-23T17:42:48.178Z] "- - -" 0 - "-" "-" 906 1302575 56 - "-" "-" "-" "-" "151.101.193.67:443" outbound|443||edition.cnn.com 10.0.5.36:43256 10.0.5.36:8443 172.16.0.173:33606 edition.cnn.com -
2020-11-23T17:48:34.633000Z	warning	envoy config	StreamAggregatedResources gRPC config stream closed: 13, 
2020-11-23T18:19:01.780475Z	warning	envoy config	StreamAggregatedResources gRPC config stream closed: 13, 
2020-11-23T18:49:28.622501Z	warning	envoy config	StreamAggregatedResources gRPC config stream closed: 13, 
2020-11-23T19:19:35.472602Z	warning	envoy config	StreamAggregatedResources gRPC config stream closed: 13, 
[2020-11-23T19:28:26.170Z] "GET /ip HTTP/2" 200 - "-" "-" 0 71 6 6 "172.16.0.173" "curl/7.61.1" "789cbf9c-cb21-9fd8-b9c8-44acc00232e3" "app.azuredns.com" "10.240.0.4:80" outbound|80||app.azuredns.com 10.0.5.36:60168 10.0.5.36:8080 172.16.0.173:36988 - -
➜  ~ (⎈ |dzvnets:default) kubectl get pod -n istio-system -o wide                                  
NAME                                    READY   STATUS    RESTARTS   AGE    IP             NODE                                NOMINATED NODE   READINESS GATES
istio-egressgateway-5dd8975cb-h262m     1/1     Running   0          133m   10.0.5.36      aks-nodepool1-38665453-vmss000001   <none>           <none>
istio-ingressgateway-76447f8f85-6kgg9   1/1     Running   0          143m   172.16.0.138   aks-router-38665453-vmss000001      <none>           <none>
istiod-75c5776d98-hwdxx                 1/1     Running   0          159m   172.16.0.182   aks-router-38665453-vmss000002      <none>           <none>



https://preliminary.istio.io/latest/blog/2018/egress-mongo/

https://github.com/istio/istio/issues/26772
