cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: helloworld
  labels:
    app: helloworld
    run: nginx
spec:
  containers:
    - name: aci-helloworld
      image: denniszielke/aci-helloworld
      ports:
        - containerPort: 80
          name: http
          protocol: TCP
      livenessProbe:
        httpGet:
          path: /
          port: 80
      readinessProbe:
        httpGet:
          path: /
          port: 80
        initialDelaySeconds: 10
        periodSeconds: 5
      resources:
        requests:
          memory: "128Mi"
          cpu: "500m"
        limits:
          memory: "256Mi"
          cpu: "1000m"
EOF

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  labels:
    app: helloworld
  name: helloworld
  namespace: default
spec:
  ports:
  - port: 80
    protocol: TCP
    targetPort: 80
  selector:
    app: helloworld
  clusterIP: None
EOF

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  labels:
    app: helloworld
  name: helloworld
  namespace: default
spec:
  ports:
  - port: 80
    protocol: TCP
    targetPort: 80
  selector:
    app: helloworld
  type: LoadBalancer
EOF


cat <<EOF | kubectl create -f -
kind: Pod
apiVersion: v1
metadata:
  name: runclient
  labels:
    run: pdemo
spec:
  containers:
    - name: ubuntu
      image: tutum/curl
      command: ["tail"]
      args: ["-f", "/dev/null"]
EOF

kubectl exec -ti runclient -- sh