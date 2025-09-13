variable "namespace" {
  description = "Namespace where Nginx Ingress Controller will be installed"
  type        = string
  default     = "ngnix-ingress-controller"
}

variable "chart_version" {
  description = "Nginx Ingress Controller Helm chart version"
  type        = string
  default     = "4.13.2"
}

variable "values_file" {
  description = "Path to the values file for Nginx Ingress Controller Helm chart"
  type        = string
  default     = "resources/ngnix-ingress-controller/ngnix-ingress-controller-values.yaml"
}