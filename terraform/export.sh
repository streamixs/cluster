terraform output -json ansible_inventory | jq -r '
  .masters.hosts[] | "\(.ansible_host) ansible_port=\(.ansible_port) ansible_user=\(.ansible_user) ansible_ssh_private_key_file=\(.ansible_ssh_private_key_file)"
' > ../ansible/inventories/masters.ini

terraform output -json ansible_inventory | jq -r '
  .workers.hosts[] | "\(.ansible_host) ansible_port=\(.ansible_port) ansible_user=\(.ansible_user) ansible_ssh_private_key_file=\(.ansible_ssh_private_key_file)"
' > ../ansible/inventories/workers.ini
