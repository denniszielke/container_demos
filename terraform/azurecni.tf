# https://www.terraform.io/docs/providers/azurerm/r/kubernetes_cluster.html
resource "azurerm_kubernetes_cluster" "akstf" {
  name                = var.cluster_name
  location            = azurerm_resource_group.aksrg.location
  resource_group_name = azurerm_resource_group.aksrg.name
  dns_prefix          = var.dns_prefix
  kubernetes_version  = var.kubernetes_version
  node_resource_group = "${azurerm_resource_group.aksrg.name}_nodes_${azurerm_resource_group.aksrg.location}"
  linux_profile {
    admin_username = "dennis"

    ssh_key {
      key_data = file("${var.ssh_public_key}")
    }
  }

  default_node_pool {
    name               = "default"
    node_count         = var.agent_count
    vm_size            = var.vm_size # "Standard_DS2_v2" #"Standard_F4s" # Standard_DS2_v2
    os_disk_size_gb    = 120
    max_pods           = 30
    vnet_subnet_id     = azurerm_subnet.aksnet.id
    type               = "VirtualMachineScaleSets" #"AvailabilitySet" #
#    availability_zones = ["1", "2"]
    node_labels = {
      pool = "default"
      environment = var.environment
    }
    tags = {
      pool = "default"
      environment = var.environment
    }
#SCALER    enable_auto_scaling = var.autoscaler
#SCALER    min_count       = var.min_agent_count
#SCALER    max_count       = var.max_agent_count
  }

  role_based_access_control {
    enabled        = true
  }

  network_profile {
      network_plugin = "azure"
      network_policy = "calico"
      service_cidr   = "10.2.0.0/24"
      dns_service_ip = "10.2.0.10"
      docker_bridge_cidr = "172.17.0.1/16"
      #pod_cidr = "" selected by subnet_id

      load_balancer_sku = "standard" # "basic"
  }

  identity {
    type = "SystemAssigned"
  }

  # service_principal {
  #   client_id     = azuread_application.aks_app.application_id
  #   client_secret = random_string.aks_sp_password.result
  #   # client_id     = var.aks_client_id
  #   # client_secret = var.aks_client_secret
  # }

  addon_profile {
    oms_agent {
      enabled                    = true
      log_analytics_workspace_id = azurerm_log_analytics_workspace.akslogs.id
    }

    kube_dashboard {
      enabled = false
    }
  }

  tags = {
    environment = var.environment
    network = "azurecni"
    rbac = "true"
    policy = "calico"
  }

  #depends_on = [azurerm_subnet.aksnet, azuread_service_principal.aks_sp, azuread_service_principal_password.aks_sp_set_pw, null_resource.after]
  depends_on = [azurerm_subnet.aksnet]
}

# merge kubeconfig from the cluster
resource "null_resource" "get-credentials" {
  provisioner "local-exec" {
    command = "az aks get-credentials --resource-group ${azurerm_resource_group.aksrg.name} --name ${azurerm_kubernetes_cluster.akstf.name}"
  }
  depends_on = [azurerm_kubernetes_cluster.akstf]
}

# set env variables for scripts
resource "null_resource" "set-env-vars" {
  provisioner "local-exec" {
    command = "export KUBE_GROUP=${azurerm_resource_group.aksrg.name}; export KUBE_NAME=${azurerm_kubernetes_cluster.akstf.name}; export LOCATION=${var.location}; export NODE_GROUP=${azurerm_kubernetes_cluster.akstf.node_resource_group}"
  }
  depends_on = [azurerm_kubernetes_cluster.akstf]
}

output "KUBE_NAME" {
    value = var.cluster_name
}

output "KUBE_GROUP" {
    value = azurerm_resource_group.aksrg.name
}

output "NODE_GROUP" {
  value = azurerm_kubernetes_cluster.akstf.node_resource_group
}

output "ID" {
    value = azurerm_kubernetes_cluster.akstf.id
}

output "HOST" {
  value = azurerm_kubernetes_cluster.akstf.kube_config.0.host
}

output "SERVICE_PRINCIPAL_ID" {
  value = azurerm_kubernetes_cluster.akstf.identity.0.principal_id
}