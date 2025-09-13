
output "argocd_admin_password" {
  value     = data.kubernetes_secret.argocd_admin_secret.data["password"]
  sensitive = true
}