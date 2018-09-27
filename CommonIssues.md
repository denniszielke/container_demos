# Common issues

## New version of azure cli does not work with az aks browse or aks get credentials

'ManagedCluster' object has no attribute 'properties'

Downgrade azure cli to working version

```
WORKING_VERSION=2.0.23-1
sudo apt-get install azure-cli=$WORKING_VERSION
```

## NIC in failed state
reset nic via cli
```
az network nic update -g MC_* -n aks-nodepool1-*-nic-0
```

## Find out source ip

```
curl ipinfo.io/ip
```

kubectl run azure-function-on-kubernetes --image=denniszielke/az-functions --port=80 --requests=cpu=100m

kubectl expose deployment azure-function-on-kubernetes --type=LoadBalancer

kubectl autoscale deploy azure-function-on-kubernetes --cpu-percent=20 --max=10 --min=1

apk add --update curl
export num=0 && while true; do curl -s -w "$num = %{time_namelookup}" "time nslookup google.com"; echo ""; num=$((num+1)); done

kubectl run alp --image=alpine:3.6

kubectl run alp --image=quay.io/collectai/alpine-curl
```
docker run --rm jess/curl -sSL ipinfo.io/ip
```

```
cat <<EOF | kubectl create -f -
kind: Pod
apiVersion: v1
metadata:
  name: curl
spec:
  containers:
    - name: curl
      image: jess/curl
      args: ["-sSL", "ipinfo.io/ip"]
EOF

kubectl logs curl
```



kubectl exec runclient -- bash -c "date && \
      echo 1 && \
      echo 2"


kubectl exec alpclient -- bash -c "var=1 && \
    while true ; do && \
      res=$( { curl -o /dev/null -s -w %{time_namelookup}\\\\n  http://www.google.com; } 2>&1 ) && \
      var=$((var+1)) && \
      if [[ $res =~ ^[1-9] ]]; then && \
        now=$(date +'%T') && \
        echo '$var slow: $res $now' && \
        break && \
      fi && \
    done"

kubectl get pods |grep runclient|cut -f1 -d\  |\
while read pod; \
 do echo "$pod writing:";\
  kubectl exec -t $pod -- bash -c \
 var=1 \
while true ; do \
  res=$( { curl -o /dev/null -s -w %{time_namelookup}\\n  http://www.google.com; } 2>&1 ) \
  var=$((var+1)) \
  if [[ $res =~ ^[1-9] ]]; then \
    now=$(date +"%T") \
    echo "$var slow: $res $now" \
    break \
  fi \
done \
done

var=1;
while true ; do
  res=$( { curl -o /dev/null -s -w %{time_namelookup}\\n  http://nginx; } 2>&1 )
  var=$((var+1))
  now=$(date +"%T")
  echo "$var slow: $res $now"
  if [[ $res =~ ^[1-9] ]]; then
    now=$(date +"%T")
    echo "$var slow: $res $now"
    break
  fi
done

var=1;
while true ; do
  res=$( { curl -o /dev/null -s -w %{time_namelookup}\\n  http://www.google.com; } 2>&1 )
  var=$((var+1))
  now=$(date +"%T")
  echo "$var slow: $res $now"
done

for i in `seq 1 100`; do time curl -s google.com > /dev/null; done

kubectl run -i --tty busybox --image=busybox --restart=Never -- sh   
