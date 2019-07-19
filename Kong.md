# Kong
https://docs.konghq.com/install/kubernetes/
https://docs.konghq.com/install/kubernetes/?_ga=2.196695532.195122953.1563518403-599058245.1563518403#postgres-backed-kong
https://hub.kubeapps.com/charts/stable/kong
https://docs.konghq.com/hub/


## kong ingress
https://github.com/Kong/kubernetes-ingress-controller/blob/master/docs/tutorials/getting-started.md

helm install --name my-kong stable/kong

helm install --name my-kong stable/kong --set ingressController.enabled=true \
  --set postgresql.enabled=false --set env.database=off

helm install --name my-kong stable/kong --set ingressController.enabled=true --set proxy.type=LoadBalancer --set postgresql.enabled=false --set env.database=off --namespace kong

export PROXY_IP=$(kubectl get -o jsonpath="{.status.loadBalancer.ingress[0].ip}" service -n kong kong-ingress-kong-proxy)

kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/yaml/echoserver.yaml

echo "
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: demo
spec:
  rules:
  - http:
      paths:
      - path: /foo
        backend:
          serviceName: echo
          servicePort: 80
" | kubectl apply -f -
