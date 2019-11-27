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

  agent_pool_profile {
    name            = "default"
    count           = var.agent_count
    vm_size         = var.vm_size # "Standard_DS2_v2" #"Standard_F4s" # Standard_DS2_v2
    os_type         = "Linux"
    os_disk_size_gb = 120
    max_pods        = 30
    vnet_subnet_id  = azurerm_subnet.aksnet.id
    type            = "VirtualMachineScaleSets" #"AvailabilitySet" #
    enable_auto_scaling = var.autoscaler
    min_count       = var.min_agent_count
    max_count       = var.max_agent_count
  }

  role_based_access_control {
    enabled        = true
  }

  network_profile {
      network_plugin = "azure"
      service_cidr   = "10.2.0.0/24"
      dns_service_ip = "10.2.0.10"
      docker_bridge_cidr = "172.17.0.1/16"
      #pod_cidr = "" selected by subnet_id
      network_policy = "calico"
      load_balancer_sku = "standard" # "basic"
  }

  service_principal {
    client_id     = var.aks_client_id
    client_secret = var.aks_client_secret
  }

  addon_profile {
    oms_agent {
      enabled                    = true
      log_analytics_workspace_id = azurerm_log_analytics_workspace.akslogs.id
    }
  }

  tags = {
    Environment = var.environment
    Network = "azurecni"
    RBAC = "true"
    Policy = "calico"
  }

  depends_on = [azurerm_subnet.aksnet]
}

# merge kubeconfig from the cluster
resource "null_resource" "get-credentials" {
  provisioner "local-exec" {
    command = "az aks get-credentials --resource-group ${azurerm_resource_group.aksrg.name} --name ${azurerm_kubernetes_cluster.akstf.name}"
  }
  depends_on = [azurerm_kubernetes_cluster.akstf]
}