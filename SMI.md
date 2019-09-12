
https://github.com/weaveworks/flagger/blob/master/docs/gitbook/tutorials/flagger-smi-istio.md

echo "
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: public-gateway
  namespace: istio-system
spec:
  selector:
    istio: ingressgateway
  servers:
    - port:
        number: 80
        name: http
        protocol: HTTP
      hosts:
        - "*"


kubectl -n istio-system port-forward svc/flagger-grafana 3000:80

export REPO=https://raw.githubusercontent.com/weaveworks/flagger/master

kubectl apply -f ${REPO}/artifacts/namespaces/test.yaml

kubectl apply -f ${REPO}/artifacts/canaries/deployment.yaml
kubectl apply -f ${REPO}/artifacts/canaries/hpa.yaml

kubectl -n test apply -f ${REPO}/artifacts/loadtester/deployment.yaml
kubectl -n test apply -f ${REPO}/artifacts/loadtester/service.yaml


https://docs.flagger.app/usage/linkerd-progressive-delivery


kubectl -n linkerd logs deployment/flagger -f | jq .msg

kubectl -n linkerd port-forward svc/linkerd-grafana 3000:80


kubectl -n test run tester --image=quay.io/stefanprodan/podinfo:1.2.1 -- ./podinfo --port=9898

kubectl -n test exec -it $(kubectl -n test get pod -l run=tester -o jsonpath='{.items[0].metadata.name}') -- /bin/sh

var=1;
while true ; do
  var=$((var+1))
  curl http://podinfo-primary:9898/status/500
  curl http://podinfo-primary:9898/delay/1
    curl http://podinfo-canary:9898/status/500
  curl http://podinfo-canary:9898/delay/1
  now=$(date +"%T")
  sleep 1
done

var=1;
while true ; do
  var=$((var+1))
  curl http://podinfo-canary:9898/status/500
  curl http://podinfo-canary:9898/delay/1
  now=$(date +"%T")
  sleep 1
done

## SMI Failure injection
https://linkerd.io/2019/07/18/failure-injection-using-the-service-mesh-interface-and-linkerd/