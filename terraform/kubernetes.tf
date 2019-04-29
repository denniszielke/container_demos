provider "kubernetes" {
  host                   = "${data.azurerm_kubernetes_cluster.akstf.kube_config.0.host}"
  username               = "${data.azurerm_kubernetes_cluster.akstf.kube_config.0.username}"
  password               = "${data.azurerm_kubernetes_cluster.akstf.kube_config.0.password}"
  client_certificate     = "${base64decode(data.azurerm_kubernetes_cluster.akstf.kube_config.0.client_certificate)}"
  client_key             = "${base64decode(data.azurerm_kubernetes_cluster.akstf.kube_config.0.client_key)}"
  cluster_ca_certificate = "${base64decode(data.azurerm_kubernetes_cluster.akstf.kube_config.0.cluster_ca_certificate)}"
}

resource "kubernetes_namespace" "example" {
  metadata {
    name = "my-first-namespace"
  }

    depends_on = ["azurerm_kubernetes_cluster.akstf"]
}

resource "kubernetes_cluster_role_binding" "tiller" {
  metadata {
    name = "tiller"
  }

  subject {
    kind = "User"
    name = "system:serviceaccount:kube-system:tiller"
  }

  role_ref {
    kind  = "ClusterRole"
    name = "cluster-admin"
  }
  
  depends_on = ["azurerm_kubernetes_cluster.akstf"]
}