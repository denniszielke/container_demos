# azure subscription id
variable "subscription_id" {
    default = ""
}


# azure ad tenant id
variable "tenant_id" {
    default = ""
}

# aks service principal
variable "aks_client_secret" {
     default = ""
}

# aks service principal secret
variable "aks_client_id" {
     default = ""
}

# default tags applied to all resources
variable "environment" {
    default = "stg"
}

# number of aks worker nodes
variable "agent_count" {
    default = 3
}

variable "autoscaler" {
    default = true
}

variable "min_agent_count" {
    default = 3
}
variable "max_agent_count" {
    default = 5
}

variable "vm_size" {
    default = "Standard_DS2_v2"
}

# kubernetes version
variable "kubernetes_version" {
    default = "1.14.8"
}
# default ssh key
variable "ssh_public_key" {
    default = "~/.ssh/id_rsa.pub"
}
# dns prefix used for azure resources
variable "dns_prefix" {
    default = "dzdemo3"
}
# cluster name
variable "cluster_name" {
    default = "demo3"
}
# resource group for all resources
variable "resource_group_name" {
    default = "demo3"
}

variable "location" {
    default = "WestEurope"
}