
# https://www.terraform.io/docs/providers/azuread/index.html
provider "azuread" {
  version = "~> 0.3"
}
resource "azuread_application" "aks_app" {
    name = "${var.cluster_name}-sp"
    identifier_uris = ["http://${var.cluster_name}-sp"]
    available_to_other_tenants = false
}
 
# https://www.terraform.io/docs/providers/azuread/r/service_principal.html
resource "azuread_service_principal" "aks_sp" {
    application_id = "${azuread_application.aks_app.application_id}"
}
 
resource "random_string" "aks_sp_password" {
    length  = 16
    special = false

    keepers = {
        service_principal = "${azuread_service_principal.aks_sp.id}"
    }
}
 
# https://www.terraform.io/docs/providers/azurerm/guides/migrating-to-azuread.html
resource "azuread_service_principal_password" "aks_sp_set_pw" {
  service_principal_id = "${azuread_service_principal.aks_sp.id}"
  value                = "${random_string.aks_sp_password.result}"
  end_date             = "2020-01-01T01:02:03Z" # "2299-12-30T23:00:00Z"  # "${timeadd(timestamp(), "8760h")}"

#   lifecycle {
#     prevent_destroy = true
#   }
}