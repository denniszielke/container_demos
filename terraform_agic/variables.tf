# azure subscription id

# Terraform backend

terraform {
  backend "azurerm" {
    resource_group_name  = "VAR_KUBE_RG"
    storage_account_name = "VAR_TERRAFORM_NAME"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}

variable "subscription_id" {
    default = ""
}

# azure ad tenant id
variable "tenant_id" {
    default = ""
}

# default tags applied to all resources
variable "environment" {
    default = "stg"
}

# number of aks worker nodes
variable "agent_count" {
    default = 2
}

variable "vm_size" {
    default = "Standard_DS2_v2"
}

variable "ad_admin_group_id" {
    default = ""
}

# kubernetes version
variable "kubernetes_version" {
    default = "1.18.18"
}
# default ssh key
variable "ssh_public_key" {
    default = "~/.ssh/id_rsa.pub"
}
# deployment prefix used for azure resources
variable "deployment_name" {
    default = ""
}
# resource group for all resources
variable "resource_group_name" {
    default = ""
}

variable "location" {
    default = "WestEurope"
}