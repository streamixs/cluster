variable "kubeconfig" {
  description = "Path to the kubeconfig file"
  type        = string
  default     = "~/.talos/kubeconfig-prod"
}

variable "argocd_oidc_client_id" {
  description = "Pocket-ID OIDC client ID for ArgoCD (empty disables OIDC)"
  type        = string
  default     = ""
}

variable "argocd_oidc_client_secret" {
  description = "Pocket-ID OIDC client secret for ArgoCD"
  type        = string
  sensitive   = true
  default     = ""
}

variable "argocd_oidc_admin_group" {
  description = "Pocket-ID group mapped to the ArgoCD admin role"
  type        = string
  default     = ""
}
