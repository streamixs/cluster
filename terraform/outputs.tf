
# output "argocd_admin_password" {
#   value     = module.argocd.argocd_admin_password
#   sensitive = true
# }

output "ansible_inventory" {
  value = {
    masters = {
      hosts = {
        for name, node in var.k8s_nodes : name => {
          ansible_host                 = node.ip
          ansible_user                 = node.ssh_user
          ansible_port                 = node.port
          ansible_ssh_private_key_file = node.ssh_key_path
        } if node.is_master
      }
    }
    workers = {
      hosts = {
        for name, node in var.k8s_nodes : name => {
          ansible_host                 = node.ip
          ansible_user                 = node.ssh_user
          ansible_port                 = node.port
          ansible_ssh_private_key_file = node.ssh_key_path
        } if !node.is_master
      }
    }
  }
}
