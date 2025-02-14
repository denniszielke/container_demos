# Egress gateway operator

https://github.com/Azure/kube-egress-gateway/tree/main
https://github.com/Azure/kube-egress-gateway/blob/main/docs/troubleshooting.md


## Install operator
```

cat <<EOF | kubectl apply -f -
apiVersion: egressgateway.kubernetes.azure.com/v1alpha1
kind: StaticGatewayConfiguration
metadata:
  name: mygateway1
  namespace: mynamespace
spec:
  gatewayVmssProfile:
    vmssResourceGroup: dzlockd7_dzlockd7_nodes_uksouth
    vmssName: aks-nodepool1-20019944-vmss
    publicIpPrefixSize: 31
  provisionPublicIps: true
  defaultRoute: staticEgressGateway
  excludeCidrs:
    - 10.244.0.0/16
    - 10.245.0.0/16
EOF

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: samplepod
  namespace: mynamespace
  annotations:
    kubernetes.azure.com/static-gateway-configuration: mygateway1 # required
spec:
  containers:
    - name: samplepod
      command: ["/bin/ash", "-c", "trap : TERM INT; sleep infinity & wait"]
      image: alpine
EOF

kubectl apply -f logging/dummy-logger/depl-explorer.yaml

kubectl apply -f logging/dummy-logger/svc-cluster-explorer.yaml

kubectl describe staticcgatewayconfiguration -n mynamespace

kubectl describe gatewaylbconfiguration

kubectl logs -f -n kube-egress-gateway-system kube-egress-gateway-controller-manage

kubectl get gatewaystatus -A

```