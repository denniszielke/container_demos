# Rancher on Azure

## Install Rancher on a vm
https://rancher.com/docs/rancher/v2.x/en/quick-start-guide/deployment/quickstart-manual-setup/#1-provision-a-linux-host

DNS_NAME=
ssh dennis@$DNS_NAME

docker run -d --restart=unless-stopped \
  -p 80:80 -p 443:443 \
  rancher/rancher:latest \
  --acme-domain $DNS_NAME

open https://$DNS_NAME
