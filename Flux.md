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
