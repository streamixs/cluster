variable "namespace" {
  description = "Namespace where Argo CD will be installed"
  type        = string
  default     = "argocd"
}

variable "chart_version" {
  description = "Argo CD Helm chart version"
  type        = string
  # renovate: datasource=helm depName=argo-cd registryUrl=https://argoproj.github.io/argo-helm
  default = "9.4.12"
}

variable "values_file" {
  description = "Path to the values file for Argo CD Helm chart"
  type        = string
  default     = "resources/argocd/argocd-values.yaml"
}

variable "sops_age_key_file" {
  description = "Path to the sops age key file"
  type        = string
  default     = "../.config/age.agekey"
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

variable "argocd_oidc_admin_email" {
  description = "Pocket-ID email mapped to the ArgoCD admin role"
  type        = string
  default     = ""
}
