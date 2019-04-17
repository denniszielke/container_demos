# Ambassador
https://www.getambassador.io/user-guide/helm/

```
helm upgrade --install --wait amb stable/ambassador
export SERVICE_IP=$(kubectl get svc --namespace default ambassador -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

```

kubectl apply -f https://getambassador.io/yaml/ambassador/ambassador-rbac.yaml

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