variable "kubeconfig" {
  description = "Path to the kubeconfig file"
  type        = string
  default     = "~/.kube/config"
}


variable "k8s_nodes" {
  type = map(object({
    ip           = string
    is_master    = bool
    cpu          = number
    memory       = number
    disk_size    = number
    ssh_user     = optional(string, "code-ex")
    ssh_key_path = optional(string, "~/.lima/_config/user")
    port         = optional(number, 32222)
  }))
  default = {
    master-01 = {
      ip        = "127.0.0.1",
      ssh_user  = "code-ex",
      is_master = true,
      cpu       = 4,
      memory    = 8192,
      disk_size = 50
      port      = 51379
    },
    worker-01 = {
      ip        = "127.0.0.1",
      ssh_user  = "code-ex",
      is_master = false,
      cpu       = 2,
      memory    = 4096,
      disk_size = 50
      port      = 51422
    },
    worker-02 = {
      ip        = "127.0.0.1",
      ssh_user  = "code-ex",
      is_master = false,
      cpu       = 2,
      memory    = 4096,
      disk_size = 50
      port      = 51536
    }
  }
}
