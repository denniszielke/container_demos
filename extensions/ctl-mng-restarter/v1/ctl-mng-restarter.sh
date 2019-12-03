#!/bin/bash

sudo mkdir /opt/msifix
sudo chmod o+rw /opt/msifix

set -x

echo "starting... v1" >> /opt/msifix/out.log
echo $(date +"%T") >> /opt/msifix/out.log

echo $(date) " - Starting Script"

echo $(date) " - Setting kubeconfig"
export KUBECONFIG=/var/lib/kubelet/kubeconfig

echo $(date) " - Waiting for API Server to start"
kubernetesStarted=1
for i in {1..600}; do
    if [ -e /usr/local/bin/kubectl ]
    then
        if /usr/local/bin/kubectl cluster-info
        then
            echo "kubernetes started"
            kubernetesStarted=0
            break
        fi
    else
        if /usr/bin/docker ps | grep apiserver
        then
            echo "kubernetes started"
            kubernetesStarted=0
            break
        fi
    fi
    sleep 1
done
if [ $kubernetesStarted -ne 0 ]
then
    echo "kubernetes did not start"
    exit 1
fi

master_nodes() {
    kubectl get no -L kubernetes.io/role -l kubernetes.io/role=master --no-headers -o jsonpath="{.items[*].metadata.name}" | tr " " "\n" | sort | head -n 1
}

wait_for_master_nodes() {
    ATTEMPTS=90
    SLEEP_TIME=10

    ITERATION=0
    while [[ $ITERATION -lt $ATTEMPTS ]]; do
        echo $(date) " - Is kubectl returning master nodes? (attempt $(( $ITERATION + 1 )) of $ATTEMPTS)"

        FIRST_K8S_MASTER=$(master_nodes)

        if [[ -n $FIRST_K8S_MASTER ]]; then
            echo $(date) " - kubectl is returning master nodes"
            return
        fi

        ITERATION=$(( $ITERATION + 1 ))
        sleep $SLEEP_TIME
    done

    echo $(date) " - kubectl failed to return master nodes in the alotted time"
    return 1
}

if ! wait_for_master_nodes; then
    echo $(date) " - Error while waiting for kubectl to output master nodes. Exiting"
    exit 1
fi



echo $(date +"%T") >> /opt/msifix/out.log
sleep 60
echo $(date +"%T") >> /opt/msifix/out.log
docker restart $(docker ps  -q)
echo $(date +"%T") >> /opt/msifix/out.log
PODNAME=$(kubectl -n kube-system get pod -l "component=kube-controller-manager" -o jsonpath='{.items[0].metadata.name}')
kubectl -n kube-system logs $PODNAME >> /opt/msifix/out.log
echo $(date +"%T") >> /opt/msifix/out.log