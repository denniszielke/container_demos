# Kong
https://docs.konghq.com/install/kubernetes/
https://docs.konghq.com/install/kubernetes/?_ga=2.196695532.195122953.1563518403-599058245.1563518403#postgres-backed-kong
https://hub.kubeapps.com/charts/stable/kong
https://docs.konghq.com/hub/


## kong ingress
https://github.com/Kong/kubernetes-ingress-controller/blob/master/docs/tutorials/getting-started.md

helm install --name kong-ingress stable/kong

helm install --name kong-ingress stable/kong --set ingressController.enabled=true \
  --set postgresql.enabled=true --set env.database=off --namespace kong

helm install --name kong-ingress stable/kong --set ingressController.enabled=true --set proxy.type=LoadBalancer --set postgresql.enabled=false --set env.database=off --namespace kong

IP=
DB_HOST=kong.postgres.database.azure.com
DB_PW=
DB_USER=kongadmin
env:
  database: postgres
  pg_host: kong.postgres.database.azure.com
  pg_password: 
  pg_user: 

helm install --name kong-ingress stable/kong --set ingressController.enabled=true --set proxy.type=LoadBalancer --set proxy.loadBalancerIP=$IP --set postgresql.enabled=false --set env.database=kong   --set env.pg_host=$DB_HOST --set env.pg_password=$DB_PW --set env.pg_user=$DB_USER --set env.pg_port=5432 --namespace kong

helm install --name kong-ingress stable/kong --set ingressController.enabled=true --set proxy.type=LoadBalancer --set proxy.loadBalancerIP=$IP --set env.cassandra_contact_points= --set env.cassandra_port=
--namespace kong
	
helm install --name kong-ingress stable/kong --set ingressController.enabled=true --set proxy.type=LoadBalancer --set proxy.loadBalancerIP=$IP --namespace kong

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


## Konga

helm repo add konga 'https://raw.githubusercontent.com/denniszielke/konga/master'
helm repo update
helm search konga
NAME            	VERSION	DESCRIPTION
sample/aerospike	0.1.2  	A Helm chart for Aerospike in Kubernetes

helm install --name konga konga/konga --namespace kong

export POD_NAME=$(kubectl get pods --namespace kong -l "app.kubernetes.io/name=konga,app.kubernetes.io/instance=konga" -o jsonpath="{.items[0].metadata.name}")

kubectl set env deploy -n kong konga NODE_TLS_REJECT_UNAUTHORIZED=0

echo "Visit http://127.0.0.1:1337 to use your application"

kubectl port-forward $POD_NAME --namespace kong 8080:1337


kong-ingress-kong-admin
https://kong-ingress-kong-admin:8444

