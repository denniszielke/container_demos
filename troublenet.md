## Trace network
apt-get install curl

apt-get install nc

nc -ul 15683

nc -ul -p 15683

nc 
30102

kubectl get events --sortby .lastTimeStamp -w


## ksniff

(
  set -x; cd "$(mktemp -d)" &&
  curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/krew.tar.gz" &&
  tar zxvf krew.tar.gz &&
  KREW=./krew-"$(uname | tr '[:upper:]' '[:lower:]')_$(uname -m | sed -e 's/x86_64/amd64/' -e 's/arm.*$/arm/')" &&
  "$KREW" install krew
)
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"


kubectl krew install sniff

kubectl >= 1.12:
kubectl sniff <POD_NAME> [-n <NAMESPACE_NAME>] [-c <CONTAINER_NAME>] [-i <INTERFACE_NAME>] [-f <CAPTURE_FILTER>] [-o OUTPUT_FILE] [-l LOCAL_TCPDUMP_FILE] [-r REMOTE_TCPDUMP_FILE]

POD_NAME: Required. the name of the kubernetes pod to start capture it's traffic.
NAMESPACE_NAME: Optional. Namespace name. used to specify the target namespace to operate on.
CONTAINER_NAME: Optional. If omitted, the first container in the pod will be chosen.
INTERFACE_NAME: Optional. Pod Interface to capture from. If omitted, all Pod interfaces will be captured.
CAPTURE_FILTER: Optional. specify a specific tcpdump capture filter. If omitted no filter will be used.
OUTPUT_FILE: Optional. if specified, ksniff will redirect tcpdump output to local file instead of wireshark. Use '-' for stdout.
LOCAL_TCPDUMP_FILE: Optional. if specified, ksniff will use this path as the local path of the static tcpdump binary.
REMOTE_TCPDUMP_FILE: Optional. if specified, ksniff will use the specified path as the remote path to upload static tcpdump to.

kubectl sniff  <your-apache-pod-name> -p

kubectl sniff <your-apache-pod-name>  -f "port 8080" -p

kubectl sniff <your-coredns-pod-name> -p -n kube-system -o dns.pcap


kubectl exec -it <your-apache-pod-name> -- curl kubesandclouds.com
