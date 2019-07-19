#!/usr/bin/env bash

# Get URLs for most recent versions
terraform_url=$(curl --silent https://releases.hashicorp.com/index.json | jq '{terraform}' | egrep "darwin.*64" | sort -rh | head -1 | awk -F[\"] '{print $4}')

TERRA_PATH=$HOME/lib/terraform/terraform

# Create a move into directory.
cd
mkdir packer
mkdir terraform && cd $_

# Download Terraform. URI: https://www.terraform.io/downloads.html
curl -o terraform.zip $terraform_url
# Unzip and install
unzip terraform.zip

# Change directory to Packer
cd ~/packer

# Download Packer. URI: https://www.packer.io/downloads.html
curl -o packer.zip $packer_url
# Unzip and install
unzip packer.zip

echo '
# Terraform & Packer Paths.
export PATH=~/terraform/:~/packer/:$PATH
' >>~/.bash_profile

source ~/.bash_profile
