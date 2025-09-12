variable "namespace" {
  description = "Namespace where Argo CD will be installed"
  type        = string
  default     = "argocd"
}

variable "chart_version" {
  description = "Argo CD Helm chart version"
  type        = string
  default     = "8.3.7"
}

variable "values_file" {
  description = "Path to the values file for Argo CD Helm chart"
  type        = string
  default     = "resources/argocd/argocd-values.yaml"
}
