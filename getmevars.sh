echo "getting clusters"
az aks list -o table

#echo $clusterlist

#echo $clusterlist

export cluster_id="$1"

if [ "$cluster_id" == "" ]; then
echo "which cluster id to get?"
read -n 1 cluster_id
echo
fi

az aks list -o json > table.json

#az aks list -o tsv | awk 'NR==$(cluster_id)'  | cut -f 5 | tr -d " "
# name
export KUBE_NAME=$(cat table.json | jq -r ".[$cluster_id].name" )
# resource id
export KUBE_ID=$(cat table.json | jq -r ".[$cluster_id].id" )
# version
export KUBE_VERSION=$(cat table.json | jq -r ".[$cluster_id].kubernetesVersion" )
# location
export LOCATION=$(cat table.json | jq -r ".[$cluster_id].location" )
# version
export NODE_GROUP=$(cat table.json | jq -r ".[$cluster_id].nodeResourceGroup" )
# location
export KUBE_GROUP=$(cat table.json | jq -r ".[$cluster_id].resourceGroup" )
# service principal id
export SERVICE_PRINCIPAL_ID=$(cat table.json | jq -r ".[$cluster_id].servicePrincipalProfile.clientId" )
echo "KUBE_NAME=$KUBE_NAME"
echo "LOCATION=$LOCATION"
echo "KUBE_GROUP=$KUBE_GROUP"
echo "KUBE_VERSION=$KUBE_VERSION"
echo "NODE_GROUP=$NODE_GROUP"
echo "SERVICE_PRINCIPAL_ID=$SERVICE_PRINCIPAL_ID"

rm table.json
#az aks list -o table | awk 'NR==3{print $2}'
#export KUBE_VERSION=$(az aks list -o tsv | awk 'NR==2'  | cut -f 5 | tr -d " ")