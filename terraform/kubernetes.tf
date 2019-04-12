provider "kubernetes" {
  host = "KUBE_MASTER_ENDPOINT"

  client_certificate     = "${file("~/.kube/client-cert.pem")}"
  client_key             = "${file("~/.kube/client-key.pem")}"
  cluster_ca_certificate = "${file("~/.kube/cluster-ca-cert.pem")}"
}

# kube config and helm init
resource "local_file" "kube_config" {
  # kube config
  filename = "${var.K8S_KUBE_CONFIG}"
  content  = "${azurerm_kubernetes_cluster.main.kube_config_raw}"

  # helm init
  provisioner "local-exec" {
    command = "helm init --client-only"
    environment {
      KUBECONFIG = "${var.K8S_KUBE_CONFIG}"
      HELM_HOME  = "${var.K8S_HELM_HOME}"
    }
  }
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