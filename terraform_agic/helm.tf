provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.akstf.kube_admin_config.0.host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.akstf.kube_admin_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.akstf.kube_admin_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.akstf.kube_admin_config.0.cluster_ca_certificate)
}

# https://www.terraform.io/docs/providers/helm/index.html
provider "helm" {
  kubernetes {
    load_config_file = false
    host                   = azurerm_kubernetes_cluster.akstf.kube_admin_config.0.host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.akstf.kube_admin_config.0.client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.akstf.kube_admin_config.0.client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.akstf.kube_admin_config.0.cluster_ca_certificate)
    config_path = "ensure-that-we-never-read-kube-config-from-home-dir"
  }
}


resource "kubernetes_namespace" "dummy-logger-ns" {
  metadata {
    name = "demo"
  }

  depends_on = [azurerm_kubernetes_cluster.akstf]
}

resource "null_resource" "delay_charts" {
  provisioner "local-exec" {
    command = "sleep 100"
  }

  triggers = {
    "before" = kubernetes_namespace.dummy-logger-ns.id
  }
}

resource "null_resource" "after_charts" {
  depends_on = [null_resource.delay_charts]
}