terraform {
  required_version = ">= 1.3.0"
}

module "k8s_node" {
  for_each = var.k8s_nodes

  source               = "./resources/init"
  node_name            = each.key
  node_ip              = each.value.ip
  is_master            = each.value.is_master
  ssh_user             = each.value.ssh_user
  ssh_private_key_path = each.value.ssh_key_path
  cpu                  = each.value.cpu
  memory               = each.value.memory
  disk_size            = each.value.disk_size
  port                 = each.value.port
}

# resource "null_resource" "wait_for_k8s" {
#   depends_on = [module.k8s_node]

#   provisioner "local-exec" {
#     command = <<-EOT
#       until kubectl get nodes --kubeconfig=<CHEMIN_VERS_KUBECONFIG> | grep -E "Ready|master|worker"; do
#         echo "En attente que les nœuds soient prêts..."
#         sleep 10
#       done
#     EOT
#   }
# }


# module "argocd" {
#   depends_on = [
#     null_resource.wait_for_k8s
#   ]
#   source = "./resources/argocd"
# }
