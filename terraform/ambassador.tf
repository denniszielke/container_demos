# https://www.terraform.io/docs/providers/helm/index.html
provider "helm" {
  kubernetes {
    load_config_file = false
    host                   = azurerm_kubernetes_cluster.akstf.kube_config.0.host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.akstf.kube_config.0.client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.akstf.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.akstf.kube_config.0.cluster_ca_certificate)
    config_path = "ensure-that-we-never-read-kube-config-from-home-dir"
  }
}

# Create Static Public IP Address to be used by Ingress
resource "azurerm_public_ip" "ambassador_ingress" {
  name                         = "ambassador-ingress-pip"
  location                     = "${azurerm_kubernetes_cluster.akstf.location}"
  resource_group_name          = "${azurerm_kubernetes_cluster.akstf.node_resource_group}"
  allocation_method            = "Static"
  sku                          = "Standard"
  domain_name_label            = var.dns_prefix

  depends_on = ["azurerm_kubernetes_cluster.akstf"]
}

# https://www.terraform.io/docs/providers/helm/repository.html
data "helm_repository" "stable" {
    name = "stable"
    url  = "https://kubernetes-charts.storage.googleapis.com"
}

# Install ambassador Ingress using Helm Chart
# https://www.terraform.io/docs/providers/helm/release.html
# https://github.com/helm/charts/tree/master/stable/ambassador
resource "helm_release" "ambassador_ingress" {
  name       = "ambassador-ingress"
  repository = "${data.helm_repository.stable.metadata.0.name}"
  chart      = "ambassador"
  namespace  = "kube-system"
  force_update = "true"
  timeout = "500"

  set {
    name  = "service.externalTrafficPolicy"
    value = "Local"
  }

  set {
    name  = "service.loadBalancerIP"
    value = "${azurerm_public_ip.ambassador_ingress.ip_address}"
  }

  depends_on = ["azurerm_kubernetes_cluster.akstf", "azurerm_public_ip.ambassador_ingress", "null_resource.after_charts"]
}