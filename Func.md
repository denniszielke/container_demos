mkdir azfunction-on-k8s

cd azfunction-on-k8s

func init . --docker --sample

func host start

docker build -t az-func-doag .
docker tag az-func-doag denniszielke/az-func-doag
docker push denniszielke/az-func-doag

kubectl run azure-function-on-kubernetes --image=denniszielke/a-func-doag --port=80 --requests=cpu=100m

kubectl expose deployment azure-function-on-kubernetes --type=LoadBalancer

kubectl autoscale deploy azure-function-on-kubernetes --cpu-percent=20 --max=10 --min=1

while true
do
curl http://52.191.15.98/api/httpfunction/?name=Dennis
done

kubectl run azure-function-on-kubernetes --image=denniszielke/az-functions --port=80 --requests=cpu=100m

kubectl expose deployment azure-function-on-kubernetes --type=LoadBalancer

kubectl autoscale deploy azure-function-on-kubernetes --cpu-percent=20 --max=10 --min=1

helm install azure/wordpress --name wordpress --namespace wordpress --set resources.requests.cpu=0


vsce env create --name dzdevenv --location eastus

git clone https://github.com/Azure/vsce.git

cd vsce/samples/nodejs/getting-started/webfrontend

vsce init --public

vsce env list

vsce up

https://docs.microsoft.com/en-gb/visualstudio/connected-environment/get-started-nodejs-03

helm install azure/wordpress --name wordpress --namespace wordpress --set resources.requests.cpu=0
