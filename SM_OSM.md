

https://blog.nillsf.com/index.php/2020/08/11/taking-the-open-service-mesh-for-a-test-drive/


wget https://github.com/openservicemesh/osm/releases/download/v0.4.0/osm-v0.4.0-darwin-amd64.tar.gz
tar -xvzf osm-v0.3.0-darwin-amd64.tar.gz

cp darwin-amd64/osm ~/lib/osm 
alias osm='/Users/dennis/lib/osm/osm' 


osm install


git clone https://github.com/openservicemesh/osm.git
cd osm


https://github.com/openservicemesh/osm/blob/main/demo/README.md

https://github.com/openservicemesh/osm/blob/main/demo/README.md

cat <<EOF | kubectl apply -f -
kind: TrafficTarget
apiVersion: access.smi-spec.io/v1alpha2
metadata:
  name: bookbuyer-access-bookstore
  namespace: "bookstore"
spec:
  destination:
    kind: ServiceAccount
    name: bookstore
    namespace: "bookstore"
  rules:
  - kind: HTTPRouteGroup
    name: bookstore-service-routes
    matches:
    - buy-a-book
    - books-bought
  sources:
  - kind: ServiceAccount
    name: bookbuyer
    namespace: "$BOOKBUYER_NAMESPACE"


# TrafficTarget is deny-by-default policy: if traffic from source to destination is not
# explicitly declared in this policy - it will be blocked.
# Should we ever want to allow traffic from bookthief to bookstore the block below needs
# uncommented.

  - kind: ServiceAccount
    name: bookthief
    namespace: "bookthief"


kubectl edit TrafficTarget bookbuyer-access-bookstore-v1 -n bookstore

kubectl edit trafficsplits bookstore-split -n bookstore