Tigera

https://docs.tigera.io/getting-started/kubernetes/aks

# StorageClass

cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: tigera-elasticsearch
parameters:
  cachingmode: ReadOnly
  kind: Managed
  storageaccounttype: Premium_LRS
provisioner: kubernetes.io/azure-disk
reclaimPolicy: Retain
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
EOF


kubectl create -f https://docs.tigera.io/manifests/tigera-operator.yaml


kubectl create -f https://docs.tigera.io/manifests/tigera-prometheus-operator.yaml


kubectl create secret generic tigera-pull-secret \
    --type=kubernetes.io/dockerconfigjson -n tigera-operator \
    --from-file=.dockerconfigjson=tigera-microsoft-dt-auth.json


kubectl create -f license.yaml


# Access

https://docs.tigera.io/getting-started/cnx/access-the-manager#access-using-port-forwarding

cat <<EOF | kubectl apply -f -
kind: Service
apiVersion: v1
metadata:
  name: tigera-manager-external
  namespace: tigera-manager
spec:
  type: LoadBalancer
  selector:
    k8s-app: tigera-manager
  externalTrafficPolicy: Local
  ports:
  - port: 9443
    targetPort: 9443
    protocol: TCP
EOF

kubectl port-forward -n tigera-manager service/tigera-manager 9443:9443

kubectl create sa jane -n default

kubectl create clusterrolebinding jane-access --clusterrole tigera-network-admin --serviceaccount default:jane

kubectl get secret $(kubectl get serviceaccount jane -o jsonpath='{range .secrets[*]}{.name}{"\n"}{end}' | grep token) -o go-template='{{.data.token | base64decode}}' && echo


# egress gateway


kubectl patch felixconfiguration.p default --type='merge' -p \
    '{"spec":{"egressIPSupport":"EnabledPerNamespace"}}'

kubectl apply -f - <<EOF
apiVersion: projectcalico.org/v3
kind: IPPool
metadata:
  name: egress-ippool-1
spec:
  cidr: 10.0.5.0/27
  blockSize: 31
  nodeSelector: "!all()"
EOF


kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: egress-gateway
  namespace: default
  labels:
    egress-code: red
spec:
  replicas: 1
  selector:
    matchLabels:
      egress-code: red
  template:
    metadata:
      annotations:
        cni.projectcalico.org/ipv4pools: "[\"egress-ippool-1\"]"
      labels:
        egress-code: red
    spec:
      imagePullSecrets:
      - name: tigera-pull-secret
      nodeSelector:
        kubernetes.io/os: linux
        workload: router
      containers:
      - name: egress-gateway
        image: quay.io/tigera/egress-gateway:v3.4.0
        env:
        - name: EGRESS_POD_IP
          valueFrom:
            fieldRef:
              fieldPath: status.podIP
        securityContext:
          privileged: true
      terminationGracePeriodSeconds: 0
EOF


cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: centos
  annotations:
    egress.projectcalico.org/selector: egress-code == 'red'
    egress.projectcalico.org/namespaceSelector: projectcalico.org/name == 'default'
spec:
  containers:
  - name: centos
    image: centos
    ports:
    - containerPort: 80
    command:
    - sleep
    - "3600"
EOF