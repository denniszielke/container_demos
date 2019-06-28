
# Linkerd Basics
https://linkerd.io/2/getting-started/

export KUBECONFIG=~/kubecon-workshop-20-kubeconfig
export PATH=$PATH:$HOME/.linkerd2/bin

## setup books app

curl -sL https://run.linkerd.io/booksapp.yml \
  | kubectl apply -f -

curl -sL https://run.linkerd.io/emojivoto.yml \
  | kubectl apply -f -

kubectl apply -f booksapp.yml

kubectl delete -f booksapp.yml

linkerd install | kubectl apply -f -

see yaml
kubectl get deploy -o yaml | linkerd inject -

inject yaml
kubectl get deploy -o yaml | linkerd inject - | kubectl apply -f -
kubectl get deploy -o yaml -n $APP_NS | linkerd inject - | kubectl apply -f -

kubectl get -n emojivoto deploy -o yaml \
  | linkerd inject - \
  | kubectl apply -f -

## get swagger and create service profile
curl https://run.linkerd.io/booksapp/authors.swagger

create service profile
curl https://run.linkerd.io/booksapp/authors.swagger | linkerd profile --open-api - authors

apply service profile
curl https://run.linkerd.io/booksapp/authors.swagger | linkerd profile --open-api - authors | kubectl apply -f -

cat apps/js-calc-backend/app/swagger.json | linkerd profile --open-api - $APP_IN-calc-backend-svc | kubectl apply -f - 

check routes
linkerd routes svc/authors
linkerd routes svc/$APP_IN-calc-backend-svc -n $APP_NS

## create ingress

kubectl apply -f ingress-mandatory.yml

kubectl apply -f nginx-ingress-svc.yml

inject linkerd into ingress controller
kubectl -n ingress-nginx get deployment -o yaml | linkerd inject - | kubectl apply -f -

configure books app ingress
kubectl apply -f books-ingress.yml

Uncomment in books-ingress.yml to remove host header lookup
    # nginx.ingress.kubernetes.io/configuration-snippet: |
    #   proxy_set_header l5d-dst-override $service_name.$namespace.svc.cluster.local:7000;
    #   proxy_hide_header l5d-remote-ip;
    #   proxy_hide_header l5d-server-id;

curl -v http://34.90.58.35

linkerd routes svc/authors

## insert retries
https://linkerd.io/2/tasks/configuring-retries/
linkerd routes deploy/books --to svc/authors

linkerd routes deployment/multicalchart-backend --namespace $APP_NS --to svc/$APP_IN-calc-backend-svc --to-namespace $APP_NS

linkerd routes deployment/multicalchart-frontend --namespace $APP_NS --to deployment/multicalchart-backend --to-namespace $APP_NS -o wide


KUBE_EDITOR="nano"

kubectl edit sp/authors.default.svc.cluster.local
add isRetryable: true
  - condition:
      method: HEAD
      pathRegex: /authors/[^/]*\.json
    name: HEAD /authors/{id}.json
    isRetryable: true

kubectl edit sp/$APP_IN-calc-backend-svc.default.svc.cluster.local -n $APP_NS
kubectl edit sp/calc1-calc-backend-svc.default.svc.cluster.local

check for effective succeess
linkerd routes deploy/books --to svc/authors -o wide
linkerd routes deploy/books --to svc/authors -o wide
ROUTE                       SERVICE   EFFECTIVE_SUCCESS   EFFECTIVE_RPS   ACTUAL_SUCCESS   ACTUAL_RPS   LATENCY_P50   LATENCY_P95   LATENCY_P99
DELETE /authors/{id}.json   authors               0.00%          0.0rps            0.00%       0.0rps           0ms           0ms           0ms
GET /authors.json           authors               0.00%          0.0rps            0.00%       0.0rps           0ms           0ms           0ms
GET /authors/{id}.json      authors               0.00%          0.0rps            0.00%       0.0rps           0ms           0ms           0ms
HEAD /authors/{id}.json     authors              88.54%          2.6rps           57.44%       4.0rps           4ms          10ms          18ms
POST /authors.json          authors               0.00%          0.0rps            0.00%       0.0rps           0ms           0ms           0ms
[DEFAULT]                   authors               0.00%          0.0rps            0.00%       0.0rps           0ms           0ms           0ms

## insert timeout
https://linkerd.io/2/tasks/configuring-timeouts/
kubectl edit sp/authors.default.svc.cluster.local

insert timeout into spec
  - condition:
      method: HEAD
      pathRegex: /authors/[^/]*\.json
    isRetryable: true
    timeout: 10ms
    name: HEAD /authors/{id}.json

linkerd routes deploy/books --to svc/authors -o wide
ROUTE                       SERVICE   EFFECTIVE_SUCCESS   EFFECTIVE_RPS   ACTUAL_SUCCESS   ACTUAL_RPS   LATENCY_P50   LATENCY_P95   LATENCY_P99
DELETE /authors/{id}.json   authors               0.00%          0.0rps            0.00%       0.0rps           0ms           0ms           0ms
GET /authors.json           authors               0.00%          0.0rps            0.00%       0.0rps           0ms           0ms           0ms
GET /authors/{id}.json      authors               0.00%          0.0rps            0.00%       0.0rps           0ms           0ms           0ms
HEAD /authors/{id}.json     authors              88.54%          2.6rps           57.44%       4.0rps           4ms          10ms          18ms
POST /authors.json          authors               0.00%          0.0rps            0.00%       0.0rps           0ms           0ms           0ms
[DEFAULT]                   authors               0.00%          0.0rps            0.00%       0.0rps           0ms           0ms           0ms

linkerd routes deployment/multicalchart-frontend -n $APP_NS --to svc/calc1-calc-backend-svc -n $APP_NS -o wide

# Linkerd Security

check linkerd issuer secret
kubectl get secret linkerd-identity-issuer  -n linkerd  -o yaml

check trust root
kubectl get configmap linkerd-config -n linkerd -o yaml

https://medium.com/solo-io/linkerd-or-istio-6fcd2aad6e42

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: centos
spec:
  containers:
  - name: centoss
    image: centos
    ports:
    - containerPort: 80
    command:
    - sleep
    - "3600"
EOF

http_proxy=$HOST_IP:$(kubectl get svc l5d -o 'jsonpath={.spec.ports[0].nodePort}') curl -s http://hello
http_proxy=$INGRESS_LB:4140 curl -s http://hello
curl -skH 'l5d-dtab: /svc=>/#/io.l5d.k8s/default/admin/l5d;' https://$INGRESS_LB:4141/admin/ping

# Linkerd Debugging 

linkerd tap deploy/webapp -o wide | grep req

linkerd tap deploy/webapp -o wide --path=/authors

linkerd tap deployment/books --namespace default --to deployment/authors --to-namespace default

show all failed requests
linkerd tap deployment/authors | grep :status=503
linkerd tap deployment/authors | grep :status=503 -C 1


linkerd tap deploy/authors --to ns/default -o wide | grep rt_route="GET /authors"

invert all that do not send to any route
linkerd tap deploy/authors --to ns/default -o wide | grep -v rt_route