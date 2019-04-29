# https://www.terraform.io/docs/providers/kubernetes/index.html

provider "kubernetes" {
  host                   = "${azurerm_kubernetes_cluster.akstf.kube_config.0.host}"
  client_certificate     = "${base64decode(azurerm_kubernetes_cluster.akstf.kube_config.0.client_certificate)}"
  client_key             = "${base64decode(azurerm_kubernetes_cluster.akstf.kube_config.0.client_key)}"
  cluster_ca_certificate = "${base64decode(azurerm_kubernetes_cluster.akstf.kube_config.0.cluster_ca_certificate)}"
}

resource "kubernetes_namespace" "example" {
  metadata {
    name = "my-first-namespace"
  }

  depends_on = ["azurerm_kubernetes_cluster.akstf"]
}

resource "kubernetes_service_account" "tiller_service_account" {
  metadata {
    name = "tiller"
    namespace = "kube-system"
  }

  depends_on = ["azurerm_kubernetes_cluster.akstf"]
}

resource "kubernetes_cluster_role_binding" "tiller_cluster_role_binding" {
  metadata {
    name = "tiller"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "default"
    namespace = "kube-system"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "${kubernetes_service_account.tiller_service_account.metadata.0.name}"
    namespace = "kube-system"
  }

  depends_on = ["azurerm_kubernetes_cluster.akstf", "kubernetes_service_account.tiller_service_account"]
}