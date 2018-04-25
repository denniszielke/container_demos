https://readon.ly/post/2017-05-25-deploy-istio-to-azure-container-service/

## Install istio via helm
https://github.com/kubernetes/charts/tree/master/incubator/istio

1. Install istioctl
```
curl -L https://git.io/getIstio | sh -
```

Add to your path
```
export PATH="$PATH:/Users/dennis/labs/istio/istio-0.7.1/bin"
```

2. Add incubator chart repo
helm repo add incubator https://kubernetes-charts-incubator.storage.googleapis.com

3. Install istio without RBAC (currently not supported with AKS)
```
helm install incubator/istio --set rbac.install=false
```

If you end up with error
Error: file "incubator/istio" not found

use this workaround
```
helm install --name istio incubator/istio --namespace istio-system --devel --version 0.2.7-chart2 --set rbac.install=false
helm upgrade istio incubator/istio --reuse-values --set istio.install=true --devel --version 0.2.7-chart2 --set rbac.install=false
```

3. Check status of istio pods
```
kubectl get pods --namespace istio-system
```

Verifying the Grafana dashboard

export POD_NAME=$(kubectl get pods --namespace istio-system -l "component=istio-grafana" -o jsonpath="{.items[0].metadata.name}")
kubectl port-forward $POD_NAME 3000:3000 --namespace istio-system

echo http://127.0.0.1:3000/dashboard/db/istio-dashboard

Verifying the ServiceGraph service

export POD_NAME=$(kubectl get pods --namespace istio-system -l "component=istio-servicegraph" -o jsonpath="{.items[0].metadata.name}")
kubectl port-forward $POD_NAME 8088:8088 --namespace istio-system
echo http://127.0.0.1:8088/dotviz

4. Install demo booking app
https://istio.io/docs/guides/bookinfo.html 

kubectl apply -f samples/bookinfo/kube/bookinfo.yaml

5. Look up ingress 
```
kubectl get ingress -o wide
```

6. Delete istio
```
helm delete istio
``` 

7. Allow egress traffic

cat <<EOF | istioctl create -f -
apiVersion: config.istio.io/v1alpha2
kind: EgressRule
metadata:
  name: dogapi-egress-rule
spec:
  destination:
    service: api.thedogapi.co.uk
  ports:
    - port: 443
      protocol: https
EOF

8. Change routing weight

cat <<EOF | istioctl create -f -
apiVersion: config.istio.io/v1alpha2
kind: RouteRule
metadata:
  name: petdetailsservice-default
spec:
  destination:
    name: petdetailsservice
  route:
  - labels:
      version: v1
    weight: 50
  - labels:
      version: v2
    weight: 50
EOF

istioctl get routerule