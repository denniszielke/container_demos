# Fix DNS issue by deploying networkmonitor as a daemonset in cluster

1. Take networkmonitor image from 
https://hub.docker.com/r/containernetworking/networkmonitor/

Latest value should be
```
containernetworking/networkmonitor:v0.0.4
```

2. Take latest version and replace <azureCNINetworkMonitorImage> with it. Deploy as a daemonset using the template from here

https://github.com/Azure/acs-engine/blob/master/parts/k8s/addons/azure-cni-networkmonitor.yaml

3. Alternative deploy directly

```
kubectl apply -f https://raw.githubusercontent.com/denniszielke/container_demos/master/bestpractices/azure-cni-networkmonitor.yaml
```
