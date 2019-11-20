# data "template_file" "traefik" {
#   template = "${file("${path.module}/traefik.yaml.tmpl")}"

#   vars = {
#     #jaeger_agent_endpoint = "${var.jaeger_agent_endpoint}"
#     prometheus_enabled    = "true"
#     ssl_enabled           = "true"
#     ssl_enforced          = "false"
#     ssl_cert_base64       = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUVtekNDQTRPZ0F3SUJBZ0lKQUpBR1FsTW1DMGt5TUEwR0NTcUdTSWIzRFFFQkJRVUFNSUdQTVFzd0NRWUQKVlFRR0V3SlZVekVSTUE4R0ExVUVDQk1JUTI5c2IzSmhaRzh4RURBT0JnTlZCQWNUQjBKdmRXeGtaWEl4RkRBUwpCZ05WQkFvVEMwVjRZVzF3YkdWRGIzSndNUXN3Q1FZRFZRUUxFd0pKVkRFV01CUUdBMVVFQXhRTktpNWxlR0Z0CmNHeGxMbU52YlRFZ01CNEdDU3FHU0liM0RRRUpBUllSWVdSdGFXNUFaWGhoYlhCc1pTNWpiMjB3SGhjTk1UWXgKTURJME1qRXdPVFV5V2hjTk1UY3hNREkwTWpFd09UVXlXakNCanpFTE1Ba0dBMVVFQmhNQ1ZWTXhFVEFQQmdOVgpCQWdUQ0VOdmJHOXlZV1J2TVJBd0RnWURWUVFIRXdkQ2IzVnNaR1Z5TVJRd0VnWURWUVFLRXd0RmVHRnRjR3hsClEyOXljREVMTUFrR0ExVUVDeE1DU1ZReEZqQVVCZ05WQkFNVURTb3VaWGhoYlhCc1pTNWpiMjB4SURBZUJna3EKaGtpRzl3MEJDUUVXRVdGa2JXbHVRR1Y0WVcxd2JHVXVZMjl0TUlJQklqQU5CZ2txaGtpRzl3MEJBUUVGQUFPQwpBUThBTUlJQkNnS0NBUUVBdHVKOW13dzlCYXA2SDROdUhYTFB6d1NVZFppNGJyYTFkN1ZiRUJaWWZDSStZNjRDCjJ1dThwdTNhVTVzYXVNYkQ5N2pRYW95VzZHOThPUHJlV284b3lmbmRJY3RFcmxueGpxelUyVVRWN3FEVHk0bkEKNU9aZW9SZUxmZXFSeGxsSjE0VmlhNVFkZ3l3R0xoRTlqZy9jN2U0WUp6bmg5S1dZMnFjVnhEdUdEM2llaHNEbgphTnpWNFdGOWNJZm1zOHp3UHZPTk5MZnNBbXc3dUhUKzNiSzEzSUloeDI3ZmV2cXVWcENzNDFQNnBzdStWTG4yCjVIRHk0MXRoQkN3T0wrTithbGJ0ZktTcXM3TEFzM25RTjFsdHpITHZ5MGE1RGhkakpUd2tQclQrVXhwb0tCOUgKNFpZazErRUR0N09QbGh5bzM3NDFRaE4vSkNZK2RKbkFMQnNValFJREFRQUJvNEgzTUlIME1CMEdBMVVkRGdRVwpCQlJwZVc1dFhMdHh3TXJvQXM5d2RNbTUzVVVJTERDQnhBWURWUjBqQklHOE1JRzVnQlJwZVc1dFhMdHh3TXJvCkFzOXdkTW01M1VVSUxLR0JsYVNCa2pDQmp6RUxNQWtHQTFVRUJoTUNWVk14RVRBUEJnTlZCQWdUQ0VOdmJHOXkKWVdSdk1SQXdEZ1lEVlFRSEV3ZENiM1ZzWkdWeU1SUXdFZ1lEVlFRS0V3dEZlR0Z0Y0d4bFEyOXljREVMTUFrRwpBMVVFQ3hNQ1NWUXhGakFVQmdOVkJBTVVEU291WlhoaGJYQnNaUzVqYjIweElEQWVCZ2txaGtpRzl3MEJDUUVXCkVXRmtiV2x1UUdWNFlXMXdiR1V1WTI5dGdna0FrQVpDVXlZTFNUSXdEQVlEVlIwVEJBVXdBd0VCL3pBTkJna3EKaGtpRzl3MEJBUVVGQUFPQ0FRRUFjR1hNZms4TlpzQit0OUtCemwxRmw2eUlqRWtqSE8wUFZVbEVjU0QyQjRiNwpQeG5NT2pkbWdQcmF1SGI5dW5YRWFMN3p5QXFhRDZ0YlhXVTZSeENBbWdMYWpWSk5aSE93NDVOMGhyRGtXZ0I4CkV2WnRRNTZhbW13QzFxSWhBaUE2MzkwRDNDc2V4N2dMNm5KbzdrYnIxWVdVRzN6SXZveGR6OFlEclpOZVdLTEQKcFJ2V2VuMGxNYnBqSVJQNFhac25DNDVDOWdWWGRoM0xSZTErd3lRcTZoOVFQaWxveG1ENk5wRTlpbVRPbjJBNQovYkozVktJekFNdWRlVTZrcHlZbEpCemRHMXVhSFRqUU9Xb3NHaXdlQ0tWVVhGNlV0aXNWZGRyeFF0aDZFTnlXCnZJRnFhWng4NCtEbFNDYzkzeWZrL0dsQnQrU0tHNDZ6RUhNQjlocVBiQT09Ci0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K"
#     ssl_key_base64        = "LS0tLS1CRUdJTiBSU0EgUFJJVkFURSBLRVktLS0tLQpNSUlFb3dJQkFBS0NBUUVBdHVKOW13dzlCYXA2SDROdUhYTFB6d1NVZFppNGJyYTFkN1ZiRUJaWWZDSStZNjRDCjJ1dThwdTNhVTVzYXVNYkQ5N2pRYW95VzZHOThPUHJlV284b3lmbmRJY3RFcmxueGpxelUyVVRWN3FEVHk0bkEKNU9aZW9SZUxmZXFSeGxsSjE0VmlhNVFkZ3l3R0xoRTlqZy9jN2U0WUp6bmg5S1dZMnFjVnhEdUdEM2llaHNEbgphTnpWNFdGOWNJZm1zOHp3UHZPTk5MZnNBbXc3dUhUKzNiSzEzSUloeDI3ZmV2cXVWcENzNDFQNnBzdStWTG4yCjVIRHk0MXRoQkN3T0wrTithbGJ0ZktTcXM3TEFzM25RTjFsdHpITHZ5MGE1RGhkakpUd2tQclQrVXhwb0tCOUgKNFpZazErRUR0N09QbGh5bzM3NDFRaE4vSkNZK2RKbkFMQnNValFJREFRQUJBb0lCQUhrTHhka0dxNmtCWWQxVAp6MkU4YWFENnhneGpyY2JSdGFCcTc3L2hHbVhuQUdaWGVWcE81MG1SYW8wbHZ2VUgwaE0zUnZNTzVKOHBrdzNmCnRhWTQxT1dDTk1PMlYxb1MvQmZUK3Zsblh6V1hTemVQa0pXd2lIZVZMdVdEaVVMQVBHaWl4emF2RFMyUnlQRmEKeGVRdVNhdE5pTDBGeWJGMG5Zd3pST3ZoL2VSa2NKVnJRZlZudU1melFkOGgyMzZlb1UxU3B6UnhSNklubCs5UApNc1R2Wm5OQmY5d0FWcFo5c1NMMnB1V1g3SGNSMlVnem5oMDNZWUZJdGtDZndtbitEbEdva09YWHBVM282aWY5ClRIenBleHdubVJWSmFnRG85bTlQd2t4QXowOW80cXExdHJoU1g1U2p1K0xyNFJvOHg5bytXdUF1VnVwb0lHd0wKMWVseERFRUNnWUVBNzVaWGp1enNJR09PMkY5TStyYVFQcXMrRHZ2REpzQ3gyZnRudk1WWVJKcVliaGt6YnpsVQowSHBCVnk3NmE3WmF6Umxhd3RGZ3ljMlpyQThpM0F3K3J6d1pQclNJeWNieC9nUVduRzZlbFF1Y0FFVWdXODRNCkdSbXhKUGlmOGRQNUxsZXdRalFjUFJwZVoxMzlYODJreGRSSEdma1pscHlXQnFLajBTWExRSEVDZ1lFQXcybkEKbUVXdWQzZFJvam5zbnFOYjBlYXdFUFQrbzBjZ2RyaENQOTZQK1pEekNhcURUblZKV21PeWVxRlk1eVdSSEZOLwpzbEhXU2lTRUFjRXRYZys5aGlMc0RXdHVPdzhUZzYyN2VrOEh1UUtMb2tWWEFUWG1NZG9xOWRyQW9INU5hV2lECmRSY3dEU2EvamhIN3RZV1hKZDA4VkpUNlJJdU8vMVZpbDBtbEk5MENnWUVBb2lsNkhnMFNUV0hWWDNJeG9raEwKSFgrK1ExbjRYcFJ5VEg0eldydWY0TjlhYUxxNTY0QThmZGNodnFiWGJHeEN6U3RxR1E2cW1peUU1TVpoNjlxRgoyd21zZEpxeE14RnEzV2xhL0lxSzM0cTZEaHk3cUNld1hKVGRKNDc0Z3kvY0twZkRmeXZTS1RGZDBFejNvQTZLCmhqUUY0L2lNYnpxUStQREFQR0YrVHFFQ2dZQmQ1YnZncjJMMURzV1FJU3M4MHh3MDBSZDdIbTRaQVAxdGJuNk8KK0IvUWVNRC92UXBaTWV4c1hZbU9lV2Noc3FCMnJ2eW1MOEs3WDY1NnRWdGFYay9nVzNsM3ZVNTdYSFF4Q3RNUwpJMVYvcGVSNHRiN24yd0ZncFFlTm1XNkQ4QXk4Z0xiaUZhRkdRSDg5QWhFa0dTd1d5cWJKc2NoTUZZOUJ5OEtUCkZaVWZsUUtCZ0V3VzJkVUpOZEJMeXNycDhOTE1VbGt1ZnJxbllpUTNTQUhoNFZzWkg1TXU0MW55Yi95NUUyMW4KMk55d3ltWGRlb3VJcFZjcUlVTXl0L3FKRmhIcFJNeVEyWktPR0QyWG5YaENNVlRlL0FQNDJod294Nm02QkZpQgpvemZFa2wwak5uZmREcjZrL1p2MlQ1TnFzaWxaRXJBQlZGOTBKazdtUFBIa0Q2R1ZMUUJ4Ci0tLS0tRU5EIFJTQSBQUklWQVRFIEtFWS0tLS0tCg=="
#   }
# }

# resource "null_resource" "generate_traefik_config" {
#   provisioner "local-exec" {
#     command = "echo '${data.template_file.traefik.rendered}' > ${path.module}/traefik.yaml"
#   }

#   depends_on = ["data.template_file.traefik"]
# }

provider "helm" {
  install_tiller = "true"
  service_account = kubernetes_service_account.tiller_service_account.metadata.0.name
  # tiller_image    = "gcr.io/kubernetes-helm/tiller:v2.14.2"

  kubernetes {
    host                   = azurerm_kubernetes_cluster.akstf.kube_config.0.host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.akstf.kube_config.0.client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.akstf.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.akstf.kube_config.0.cluster_ca_certificate)
  }
}

# Create Static Public IP Address to be used by Traefik Ingress
resource "azurerm_public_ip" "traefik_ingress" {
  name                         = "traefik-ingress-pip"
  location                     = azurerm_kubernetes_cluster.akstf.location
  resource_group_name          = azurerm_kubernetes_cluster.akstf.node_resource_group
  allocation_method            = "Static"
  domain_name_label            = var.dns_prefix

  depends_on = [azurerm_kubernetes_cluster.akstf]
}

# https://www.terraform.io/docs/providers/helm/repository.html
data "helm_repository" "stable" {
    name = "stable"
    url  = "https://kubernetes-charts.storage.googleapis.com"
}

# Install traefik Ingress using Helm Chart
# https://github.com/helm/charts/tree/master/stable/traefik
# https://www.terraform.io/docs/providers/helm/release.html
resource "helm_release" "traefik_ingress" {
  name       = "traefikingress"
  repository = data.helm_repository.stable.metadata.0.name
  chart      = "traefik"
  namespace  = "kube-system"
  force_update = "true"
  timeout = "500"

  values = [
    file("${path.module}/traefik.yaml"),
  ]

  set {
    name  = "replicas"
    value = "2"
  }

  set {
    name  = "rbac.create"
    value = "true"
  }

  set {
    name  = "externalTrafficPolicy"
    value = "Local"
  }

  set {
    name  = "loadBalancerIP"
    value = azurerm_public_ip.traefik_ingress.ip_address
  }
  
  depends_on = [azurerm_kubernetes_cluster.akstf, azurerm_public_ip.traefik_ingress, null_resource.after_charts]
}