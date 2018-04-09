## Create a private hosted agent

1. Provision Ubuntu 16.04 LTS
2. Install vsts agent dependencies
https://www.visualstudio.com/en-us/docs/build/actions/agents/v2-linux
3. Create agent access token

Bash script

BUILD_SOURCESDIRECTORY

az group create --name "acicd" --location westeurope

$(releaseNameDev) . --install --force --reset-values --wait --set image.repository=$(imageRepository) --set image.backendTag=$(Build.BuildId) --set image.frontendTag=$(Build.BuildId) --set image.pullSecret=kuberegistry