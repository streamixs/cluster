variable "kubeconfig" {
  description = "Path to the kubeconfig file"
  type        = string
  default     = "~/.talos/kubeconfig-dev"
}
