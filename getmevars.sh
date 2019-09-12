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

az aks list -o tsv > table.csv

#az aks list -o tsv | awk 'NR==$(cluster_id)'  | cut -f 5 | tr -d " "
# name
export KUBE_NAME=$(cat table.csv | head -n $cluster_id | tail -1 | cut -f 5 | tr -d " ")
# resource id
export KUBE_ID=$(cat table.csv | head -n $cluster_id | tail -1 | cut -f 9 | tr -d " ")
# version
export KUBE_VERSION=$(cat table.csv | head -n $cluster_id | tail -1 | cut -f 11 | tr -d " ")
# location
export LOCATION=$(cat table.csv | head -n $cluster_id | tail -1 | cut -f 13 | tr -d " ")
# version
export NODE_GROUP=$(cat table.csv | head -n $cluster_id | tail -1 | cut -f 17 | tr -d " ")
# location
export KUBE_GROUP=$(cat table.csv | head -n $cluster_id | tail -1 | cut -f 19 | tr -d " ")
echo "KUBE_NAME=$KUBE_NAME"
echo "LOCATION=$LOCATION"
echo "KUBE_GROUP=$KUBE_GROUP"
echo "KUBE_VERSION=$KUBE_VERSION"
echo "NODE_GROUP=$NODE_GROUP"

rm table.csv
#az aks list -o table | awk 'NR==3{print $2}'
#export KUBE_VERSION=$(az aks list -o tsv | awk 'NR==2'  | cut -f 5 | tr -d " ")