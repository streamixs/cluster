variable "namespace" {
  description = "Namespace where Prometheus will be installed"
  type        = string
  default     = "monitoring"
}

variable "chart_version" {
  description = "Prometheus Helm chart version"
  type        = string
  default     = "77.6.2"
}

variable "values_file" {
  description = "Path to the values file for Prometheus Helm chart"
  type        = string
  default     = "resources/kube-prometheus-stack/kube-prometheus-stack-values.yaml"
}