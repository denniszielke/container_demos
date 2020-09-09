# https://www.terraform.io/docs/providers/kubernetes/r/storage_class.html
resource "azurerm_storage_account" "monitoring_storage" {
  name                     = "${var.dns_prefix}monistore"
  location                 = azurerm_resource_group.aksrg.location
  resource_group_name      = azurerm_resource_group.aksrg.name
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    environment = var.environment
    workload = "monitoringconfig"
  }
}

# https://www.terraform.io/docs/providers/azurerm/r/role_assignment.html
resource "azurerm_role_assignment" "storagerole" {
  scope                = azurerm_storage_account.monitoring_storage.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.aks_sp.id
  
  depends_on = [azuread_service_principal.aks_sp, azurerm_storage_account.monitoring_storage]
}

# https://www.terraform.io/docs/providers/kubernetes/r/storage_class.html
resource "kubernetes_storage_class" "azure_file_monistore" {
  metadata {
    name = "azure-file-monistore"
  }
  storage_provisioner = "kubernetes.io/azure-file"
  reclaim_policy      = "Retain"
  parameters = {
    skuName: "Standard_LRS"
    resourceGroup: azurerm_resource_group.aksrg.name
    storageAccount: azurerm_storage_account.monitoring_storage.name
  }

  depends_on = [azurerm_storage_account.monitoring_storage, azurerm_kubernetes_cluster.akstf, null_resource.after_charts]
}

resource "kubernetes_namespace" "monitoring_ns" {
  metadata {
    name = "monitoring"
  }

  depends_on = [azurerm_kubernetes_cluster.akstf]
}

# Install Grafana chart
# https://github.com/helm/charts/tree/master/stable/grafana
# https://www.terraform.io/docs/providers/helm/release.html
resource "helm_release" "my_grafana" {
  name       = "my-grafana"
  repository = "https://kubernetes-charts.storage.googleapis.com" 
  chart      = "grafana"
  namespace  = kubernetes_namespace.monitoring_ns.metadata.0.name
  force_update = "true"
  timeout = "500"

  set {
    name  = "plugins"
    value = "{grafana-azure-monitor-datasource}"
  }

  set {
    name  = "persistence.enabled"
    value = "true"
  }

  set {
    name  = "persistence.storageClassName"
    value = kubernetes_storage_class.azure_file_monistore.metadata.0.name
  }

  depends_on = [azurerm_kubernetes_cluster.akstf, null_resource.after_charts, kubernetes_storage_class.azure_file_monistore]
}

# Install Prometheus chart
# https://github.com/helm/charts/tree/master/stable/prometheus
# https://www.terraform.io/docs/providers/helm/release.html
resource "helm_release" "my_prometheus" {
  name       = "my-prometheus"
  repository = "https://kubernetes-charts.storage.googleapis.com" 
  chart      = "prometheus"
  namespace  = kubernetes_namespace.monitoring_ns.metadata.0.name
  force_update = "true"
  timeout = "500"

  set {
    name  = "alertmanager.persistence.enabled"
    value = "false"
  }

  set {
    name  = "server.persistence.enabled"
    value = "true"
  }

  set {
    name  = "server.persistence.storageClassName"
    value = kubernetes_storage_class.azure_file_monistore.metadata.0.name
  }

  depends_on = [azurerm_kubernetes_cluster.akstf, null_resource.after_charts, kubernetes_storage_class.azure_file_monistore]
}