# Grafana

kubectl -n monitoring port-forward $(kubectl -n monitoring get \
  pod -l app=grafana -o jsonpath='{.items[0].metadata.name}') 3000:3000 &