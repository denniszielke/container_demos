data "helm_repository" "datawire" {
    name = "datawire"
    url  = "https://getambassador.io"
}

# Create Static Public IP Address to be used by Ingress
resource "azurerm_public_ip" "ambassador_ingress" {
  name                         = "ambassador-ingress-pip"
  location                     = azurerm_kubernetes_cluster.akstf.location
  resource_group_name          = azurerm_kubernetes_cluster.akstf.node_resource_group
  allocation_method            = "Static"
  sku                          = "Standard"
  domain_name_label            = var.dns_prefix

  depends_on = [azurerm_kubernetes_cluster.akstf]
}

resource "kubernetes_namespace" "ambassador-ns" {
  metadata {
    name = "ambassador"
  }

  depends_on = [azurerm_kubernetes_cluster.akstf]
}

# Install ambassador Ingress using Helm Chart
# https://www.terraform.io/docs/providers/helm/release.html
# https://github.com/datawire/ambassador-chart
resource "helm_release" "ambassador_ingress" {
  name       = "ambassador-ingress"
  repository = "https://kubernetes-charts.storage.googleapis.com" 
  chart      = "ambassador"
  namespace  = "ambassador"
  force_update = "true"
  timeout = "500"

  set {
    name  = "service.externalTrafficPolicy"
    value = "Local"
  }

  set {
    name  = "service.loadBalancerIP"
    value = azurerm_public_ip.ambassador_ingress.ip_address
  }

  depends_on = [azurerm_kubernetes_cluster.akstf, kubernetes_namespace.ambassador-ns, azurerm_public_ip.ambassador_ingress, null_resource.after_charts]
}