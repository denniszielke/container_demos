# Kubeflow

## Install
https://www.kubeflow.org/docs/azure/deploy/install-kubeflow/
```
wget https://github.com/kubeflow/kfctl/releases/download/v1.1.0/kfctl_v1.1.0-0-g9a3621e_darwin.tar.gz

tar -xvf  kfctl_v1.1.0-0-g9a3621e_darwin.tar.gz 

export PATH=$PATH:~/hack/kubeflow

export KF_NAME=my-kf

export BASE_DIR=~/hack/kubeflow
export KF_DIR=${BASE_DIR}/${KF_NAME}

# Set the configuration file to use, such as the file specified below:
export CONFIG_URI="https://raw.githubusercontent.com/kubeflow/manifests/v1.1-branch/kfdef/kfctl_k8s_istio.v1.1.0.yaml"

# Generate and deploy Kubeflow:
mkdir -p ${KF_DIR}
cd ${KF_DIR}
kfctl apply -V -f ${CONFIG_URI}

kubectl port-forward svc/istio-ingressgateway -n istio-system 8080:80


```