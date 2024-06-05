resource "random_string" "k3s_token" {
  length  = 64
  special = false
}

# TODO replace null_resource with data_resource

resource "null_resource" "main_server" {
  triggers = {
    host        = var.nodes[0].host
    port        = var.nodes[0].port
    user        = var.user
    private_key_path = var.private_key_path
    k3s_exec_args    = "--tls-san ${var.nodes[0].host}"
  }

  provisioner "remote-exec" {
    when = create
    inline = [
      <<EOF
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="${self.triggers.k3s_exec_args}" K3S_TOKEN=${random_string.k3s_token.result} sh -s - server \
    --cluster-init
EOF
    ]
  }

  connection {
    host        = self.triggers.host
    port        = self.triggers.port
    type        = "ssh"
    user        = self.triggers.user
    private_key = file(self.triggers.private_key_path)
  }
}

resource "null_resource" "copy_kube_config" {
  provisioner "local-exec" {
    when    = create
    command = "mkdir -p ${path.root}/access; ssh -o StrictHostKeyChecking=no -p ${ var.nodes[0].port } -o UserKnownHostsFile=/dev/null -i ${var.private_key_path} ${var.user}@${var.nodes[0].host} sudo cat /etc/rancher/k3s/k3s.yaml > ${path.root}/access/kubeconfig"
  }

  depends_on = [ null_resource.main_server ]
}

resource "null_resource" "fix_kube_url" {
  provisioner "local-exec" {
    when    = create
    command = "sed -i 's/127.0.0.1/${var.nodes[0].host}/g' ${path.root}/access/kubeconfig"
  }
  depends_on = [ null_resource.copy_kube_config ]
}

resource "null_resource" "copy_k3s_token" {
  provisioner "local-exec" {
    when    = create
    command = "echo ${random_string.k3s_token.result} > ${path.root}/access/k3s_token"
  }

  depends_on = [ null_resource.copy_kube_config ]
}

resource "null_resource" "other_nodes" {
  count = length(var.nodes)

  triggers = {
    server_host = var.nodes[0].host
    node_type = var.nodes[count.index].type
    host = var.nodes[count.index].host
    port        = var.nodes[count.index].port
    user        = var.user
    private_key_path = var.private_key_path
  }

  provisioner "remote-exec" {
    when = create
    inline = [
<<EOF
curl -sfL https://get.k3s.io | K3S_TOKEN=${random_string.k3s_token.result} sh -s - ${self.triggers.node_type} \
    --server https://${self.triggers.server_host}:6443
EOF
    ]

  }

  provisioner "remote-exec" {
    when = destroy
    inline = [
<<EOF
if [ "${self.triggers.node_type}" = "server" ]; then
    /usr/local/bin/k3s-uninstall.sh
else
    /usr/local/bin/k3s-agent-uninstall.sh
fi
EOF
    ]
  }

  connection {
    host        = self.triggers.host
    port        = self.triggers.port
    type        = "ssh"
    user        = self.triggers.user
    private_key = file(self.triggers.private_key_path)
  }

  lifecycle {
    replace_triggered_by = [
        null_resource.main_server
    ]
  }

  depends_on = [ null_resource.main_server ]
}
