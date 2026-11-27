terraform {
  required_version = ">= 1.3.0"
}

module "argocd" {
  source = "./resources/argocd"

  argocd_oidc_client_id     = var.argocd_oidc_client_id
  argocd_oidc_client_secret = var.argocd_oidc_client_secret
  argocd_oidc_admin_email   = var.argocd_oidc_admin_email
}
