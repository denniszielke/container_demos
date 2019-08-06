# Ambassador
https://www.getambassador.io/user-guide/helm/

```

kubectl apply -f https://getambassador.io/yaml/ambassador/ambassador-rbac.yaml

IP=

helm upgrade --install --wait amb stable/ambassador
export SERVICE_IP=$(kubectl get svc --namespace default ambassador -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

helm upgrade --install --wait amb stable/ambassador --set service.loadBalancerIP=$IP --set prometheusExporter.enabled=true --namespace ambassador 



```

admin
```

export POD_NAME=$(kubectl get pods --namespace ambassador -l "app.kubernetes.io/name=ambassador,app.kubernetes.io/instance=amb" -o jsonpath="{.items[0].metadata.name}")

kubectl set env deploy -n kong konga NODE_TLS_REJECT_UNAUTHORIZED=0

kubectl port-forward $POD_NAME --namespace ambassador 8080:8877

http://localhost:8080/ambassador/v0/diag/

kubectl apply -f https://getambassador.io/yaml/tour/tour.yaml

```


```

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: ambassador
spec:
  type: LoadBalancer
  externalTrafficPolicy: Local
  ports:
   - port: 80
  selector:
    service: ambassador
EOF
```

```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: httpbin
  annotations:
    getambassador.io/config: |
      ---
      apiVersion: ambassador/v1
      kind:  Mapping
      name:  httpbin_mapping
      prefix: /httpbin/
      service: httpbin.org:80
      host_rewrite: httpbin.org
spec:
  ports:
  - name: httpbin
    port: 80
EOF
```

export SERVICE_IP=$(kubectl get svc --namespace default ambassador -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

curl $SERVICE_IP/httpbin/