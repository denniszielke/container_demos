# WASM


```
az aks nodepool add \
    --resource-group $KUBE_GROUP \
    --cluster-name $KUBE_NAME \
    --name mywasipool \
    --node-count 1 \
    --workload-runtime wasmwasi

az aks nodepool show -g $KUBE_GROUP --cluster-name $KUBE_GROUP -n mywasipool

cat <<EOF | kubectl apply -f -
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: "wasmtime-slight-v1"
handler: "slight"
scheduling:
  nodeSelector:
    "kubernetes.azure.com/wasmtime-slight-v1": "true"
---
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: "wasmtime-spin-v1"
handler: "spin"
scheduling:
  nodeSelector:
    "kubernetes.azure.com/wasmtime-spin-v1": "true"
EOF

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wasm-slight
spec:
  replicas: 1
  selector:
    matchLabels:
      app: wasm-slight
  template:
    metadata:
      labels:
        app: wasm-slight
    spec:
      runtimeClassName: wasmtime-slight-v1
      containers:
        - name: hello-slight
          image: ghcr.io/deislabs/containerd-wasm-shims/examples/slight-rust-hello:v0.3.3
          command: ["/"]
          resources:
            requests:
              cpu: 10m
              memory: 10Mi
            limits:
              cpu: 500m
              memory: 128Mi
---
apiVersion: v1
kind: Service
metadata:
  name: wasm-slight
spec:
  type: LoadBalancer
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
  selector:
    app: wasm-slight
EOF
```




## Deploy demo app

```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: krustlet-wagi-demo
  labels:
    app: krustlet-wagi-demo
  annotations:
    alpha.wagi.krustlet.dev/default-host: "0.0.0.0:3001"
    alpha.wagi.krustlet.dev/modules: |
      {
        "krustlet-wagi-demo-http-example": {"route": "/http-example", "allowed_hosts": ["https://api.brigade.sh"]},
        "krustlet-wagi-demo-hello": {"route": "/hello/..."},
        "krustlet-wagi-demo-error": {"route": "/error"},
        "krustlet-wagi-demo-log": {"route": "/log"},
        "krustlet-wagi-demo-index": {"route": "/"}
      }
spec:
  hostNetwork: true
  nodeSelector:
    kubernetes.io/arch: wasm32-wagi
  containers:
    - image: webassembly.azurecr.io/krustlet-wagi-demo-http-example:v1.0.0
      imagePullPolicy: Always
      name: krustlet-wagi-demo-http-example
    - image: webassembly.azurecr.io/krustlet-wagi-demo-hello:v1.0.0
      imagePullPolicy: Always
      name: krustlet-wagi-demo-hello
    - image: webassembly.azurecr.io/krustlet-wagi-demo-index:v1.0.0
      imagePullPolicy: Always
      name: krustlet-wagi-demo-index
    - image: webassembly.azurecr.io/krustlet-wagi-demo-error:v1.0.0
      imagePullPolicy: Always
      name: krustlet-wagi-demo-error
    - image: webassembly.azurecr.io/krustlet-wagi-demo-log:v1.0.0
      imagePullPolicy: Always
      name: krustlet-wagi-demo-log
  tolerations:
    - key: "node.kubernetes.io/network-unavailable"
      operator: "Exists"
      effect: "NoSchedule"
    - key: "kubernetes.io/arch"
      operator: "Equal"
      value: "wasm32-wagi"
      effect: "NoExecute"
    - key: "kubernetes.io/arch"
      operator: "Equal"
      value: "wasm32-wagi"
      effect: "NoSchedule"
EOF


```
