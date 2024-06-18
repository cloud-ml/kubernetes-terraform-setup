terraform {

  required_providers {
    kubernetes = {
      source  = "hashicorp/null"
      version = ">= 3.2.1"
    }
  }
}

locals {
  nodes = [
    {
      name = "node-1"
      host = "192.168.56.101"
      port = 22
      type = "server"
    },
    {
      name = "node-2"
      host = "192.168.56.102"
      port = 22
      type = "server"
    },
    {
      name = "node-3"
      host = "192.168.56.103"
      port = 22
      type = "server"
    },
  ]
}

module "k3s" {
  source      = "./k3s"
  private_key_path = "./vagrant_key"
  user        = "vagrant"
  nodes = local.nodes
  additional_k3s_args = "--flannel-iface=eth1"
}
