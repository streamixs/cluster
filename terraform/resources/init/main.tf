terraform {
  required_version = ">= 1.3.0"
}

resource "null_resource" "k8s_node" {
  connection {
    type        = "ssh"
    user        = var.ssh_user
    port        = var.port
    private_key = file(var.ssh_private_key_path)
    host        = var.node_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update -y",
      "sudo apt upgrade -y -o Dpkg::Options::=\"--force-confdef\" -o Dpkg::Options::=\"--force-confold\"",
      "sudo apt install -y python3 openssh-server curl",
      "sudo sed -i '/ swap / s/^.*$/\\#&/g' /etc/fstab",
      "sudo swapoff -a",
      "sudo modprobe overlay",
      "sudo modprobe br_netfilter",
      "echo 'net.ipv4.ip_forward=1' | sudo tee -a /etc/sysctl.conf",
      "sudo sysctl -p",
      "sudo apt install -y containerd",
      "sudo mkdir -p /etc/containerd",
      "sudo containerd config default | sudo tee /etc/containerd/config.toml",
      "sudo systemctl restart containerd",
      # Redémarre la VM pour appliquer la mise à jour du noyau
      "sudo shutdown -r +1 'Rebooting to apply kernel update'",
    ]
  }
}
