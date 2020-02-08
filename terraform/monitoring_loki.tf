data "helm_repository" "loki" {
    name = "loki"
    url  = "https://grafana.github.io/loki/charts"
}

resource "kubernetes_namespace" "loki_ns" {
  metadata {
    name = "loki"
  }

  depends_on = [azurerm_kubernetes_cluster.akstf]
}

# Install Loki chart
# https://github.com/grafana/loki/blob/master/docs/installation/helm.md
# https://www.terraform.io/docs/providers/helm/release.html
resource "helm_release" "my_loki" {
  name       = "my-loki"
  repository = data.helm_repository.loki.metadata.0.name
  chart      = "loki-stack"
  namespace  = kubernetes_namespace.loki_ns.metadata.0.name
  force_update = "true"
  timeout = "500"

  set {
    name  = "grafana.enabled"
    value = "true"
  }

  set {
    name  = "prometheus.enabled"
    value = "true"
  }

  set {
    name  = "prometheus.alertmanager.persistentVolume.enabled"
    value = "false"
  }

  set {
    name  = "prometheus.server.persistentVolume.enabled"
    value = "true"
  }

  set {
    name  = "persistence.enabled"
    value = "true"
  }

  depends_on = [azurerm_kubernetes_cluster.akstf, null_resource.after_charts]
}