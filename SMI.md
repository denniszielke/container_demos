
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