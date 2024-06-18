resource "random_string" "k3s_token" {
  length  = 64
  special = false
}

resource "terraform_data" "main_server" {

  input = {
    host        = var.nodes[0].host
    port        = var.nodes[0].port
    user        = var.user
    private_key_path = var.private_key_path
    k3s_exec_args = "--tls-san ${var.nodes[0].host}"
    additional_k3s_args = var.additional_k3s_args
  }

  provisioner "remote-exec" {
    when = create
    inline = [
      <<EOF
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="${self.input.k3s_exec_args}" K3S_TOKEN=${random_string.k3s_token.result} sh -s - server \
    --cluster-init \
    ${self.input.additional_k3s_args}
EOF
    ]
  }
  provisioner "remote-exec" {
    when = destroy
    inline = [
      "/usr/local/bin/k3s-uninstall.sh"
    ]
  }
  connection {
    host        = self.input.host
    port        = self.input.port
    type        = "ssh"
    user        = self.input.user
    private_key = file(self.input.private_key_path)
  }
}

resource "terraform_data" "copy_kube_config" {
  triggers_replace = timestamp()

  provisioner "local-exec" {
    when    = create
    command = "mkdir -p ${path.root}/access; ssh -o StrictHostKeyChecking=no -p ${ var.nodes[1].port } -o UserKnownHostsFile=/dev/null -i ${var.private_key_path} ${var.user}@${var.nodes[1].host} sudo cat /etc/rancher/k3s/k3s.yaml > ${path.root}/access/kubeconfig"
  }

  depends_on = [ terraform_data.other_nodes ]
}

resource "terraform_data" "fix_kube_url" {
  triggers_replace = terraform_data.copy_kube_config

  provisioner "local-exec" {
    when    = create
    command = "sed -i 's/127.0.0.1/${var.nodes[0].host}/g' ${path.root}/access/kubeconfig"
  }
  depends_on = [ terraform_data.copy_kube_config ]
}

resource "terraform_data" "copy_k3s_token" {
  provisioner "local-exec" {
    when    = create
    command = "echo ${random_string.k3s_token.result} > ${path.root}/access/k3s_token"
  }

  depends_on = [ terraform_data.copy_kube_config ]
}

resource "terraform_data" "other_nodes" {
  count = length(var.nodes) - 1

  input = {
    server_host = var.nodes[0].host
    node_type = var.nodes[count.index + 1].type
    host = var.nodes[count.index + 1].host
    port        = var.nodes[count.index + 1].port
    user        = var.user
    private_key_path = var.private_key_path
    k3s_exec_args = "--tls-san ${var.nodes[count.index + 1].host}"
    additional_k3s_args = var.additional_k3s_args
  }

  provisioner "remote-exec" {
    when = create
    inline = [
<<EOF
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="${self.input.k3s_exec_args}" K3S_TOKEN=${random_string.k3s_token.result} sh -s - ${self.input.node_type} \
    --server https://${self.input.server_host}:6443 \
    ${self.input.additional_k3s_args}
EOF
    ]

  }

  provisioner "remote-exec" {
    when = destroy
    inline = [
<<EOF
if [ "${self.input.node_type}" = "server" ]; then
    /usr/local/bin/k3s-uninstall.sh
else
    /usr/local/bin/k3s-agent-uninstall.sh
fi
EOF
    ]
  }

  connection {
    host        = self.input.host
    port        = self.input.port
    type        = "ssh"
    user        = self.input.user
    private_key = file(self.input.private_key_path)
  }

  lifecycle {
    replace_triggered_by = [
        terraform_data.main_server
    ]
  }

  depends_on = [ terraform_data.main_server ]
}
