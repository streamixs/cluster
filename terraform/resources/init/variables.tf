variable "node_name" {
  type = string
}

variable "node_ip" {
  type = string
}

variable "port" {
  type    = number
  default = 22

}

variable "is_master" {
  type    = bool
  default = false
}

variable "ssh_user" {
  type    = string
  default = "ubuntu"
}

variable "ssh_private_key_path" {
  type    = string
  default = "~/.ssh/id_ed25519"
}

variable "cpu" {
  type    = number
  default = 2
}

variable "memory" {
  type    = number
  default = 4096
}

variable "disk_size" {
  type    = number
  default = 50
}
