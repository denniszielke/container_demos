
RG_NAME="dzaca67" # here the deployment
LOCATION="westeurope"
SUBNET_RESOURCE_ID="

az deployment group create -g $RG_NAME -f main.bicep -p internalOnly=true

