variable "namespace" {
  description = "Namespace where Argo Rollouts will be installed"
  type        = string
  default     = "argo-rollouts"
}

variable "chart_version" {
  description = "Argo Rollouts Helm chart version"
  type        = string
  default     = "2.40.4"
}

variable "values_file" {
  description = "Path to the values file for Argo Rollouts Helm chart"
  type        = string
  default     = "resources/argo-rollouts/argo-rollouts-values.yaml"
}