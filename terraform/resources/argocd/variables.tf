variable "namespace" {
  description = "Namespace where Argo CD will be installed"
  type        = string
  default     = "argocd"
}

variable "chart_version" {
  description = "Argo CD Helm chart version"
  type        = string
  default     = "9.4.12"
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
