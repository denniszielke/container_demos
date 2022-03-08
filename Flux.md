# Flux
https://www.weave.works/technologies/gitops/
https://github.com/fluxcd/flux

https://github.com/fluxcd/flux/blob/master/docs/tutorials/get-started-helm.md

https://github.com/denniszielke/flux-get-started

https://helm.workshop.flagger.dev/
https://helm.workshop.flagger.dev/gitops-helm-workshop.png


helm upgrade -i flux \
--set helmOperator.create=true \
--set helmOperator.createCRD=false \
--set git.url=git@github.com:denniszielke/flux-get-started \
--namespace flux \
fluxcd/flux


kubectl -n flux logs deployment/flux | grep identity.pub | cut -d '"' -f2


https://github.com/gbaeke/realtimeapp-infra/blob/master/deploy/bases/realtimeapp/kustomization.yaml

https://github.com/cyrilbkr/flux2-multicluster-example/blob/main/infrastructure/common/ingress-nginx/nginx-ingress.yaml


https://docs.microsoft.com/en-us/azure/azure-arc/kubernetes/tutorial-use-gitops-flux2#work-with-parameters

https://docs.microsoft.com/en-us/cli/azure/k8s-configuration/flux?view=azure-cli-latest#az_k8s_configuration_flux_create