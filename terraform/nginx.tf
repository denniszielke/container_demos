
provider "helm" {
  install_tiller = "true"
  service_account = "${kubernetes_service_account.tiller_service_account.metadata.0.name}"

  kubernetes {
    host                   = "${azurerm_kubernetes_cluster.akstf.kube_config.0.host}"
    client_certificate     = "${base64decode(azurerm_kubernetes_cluster.akstf.kube_config.0.client_certificate)}"
    client_key             = "${base64decode(azurerm_kubernetes_cluster.akstf.kube_config.0.client_key)}"
    cluster_ca_certificate = "${base64decode(azurerm_kubernetes_cluster.akstf.kube_config.0.cluster_ca_certificate)}"
  }
}

# Create Static Public IP Address to be used by Nginx Ingress
resource "azurerm_public_ip" "nginx_ingress" {
  name                         = "nginx-ingress-pip"
  location                     = "${azurerm_kubernetes_cluster.akstf.location}"
  resource_group_name          = "${azurerm_kubernetes_cluster.akstf.node_resource_group}"
  allocation_method            = "Static"
  domain_name_label            = "${var.dns_prefix}"

  depends_on = ["azurerm_kubernetes_cluster.akstf"]
}

# https://www.terraform.io/docs/providers/helm/repository.html
data "helm_repository" "stable" {
    name = "stable"
    url  = "https://kubernetes-charts.storage.googleapis.com"
}

# Install Nginx Ingress using Helm Chart
# https://www.terraform.io/docs/providers/helm/release.html
resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress"
  repository = "${helm_repository.stable.metadata.0.name}"
  chart      = "nginx-ingress"
  namespace  = "kube-system"

  set {
    name  = "rbac.create"
    value = "true"
  }

  set {
    name  = "controller.service.externalTrafficPolicy"
    value = "Local"
  }

  set {
    name  = "controller.service.loadBalancerIP"
    value = "${azurerm_public_ip.nginx_ingress.ip_address}"
  }

  depends_on = ["azurerm_kubernetes_cluster.akstf", "azurerm_public_ip.nginx_ingress"]
}