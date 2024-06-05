terraform {

  required_providers {
    kubernetes = {
      source  = "hashicorp/null"
      version = ">= 3.2.1"
    }
  }
}

locals {
  number_of_nodes = 3
  nodes = toset([
    for i, node in range(local.number_of_nodes): {
      name = "node-${i}"
      host = "192.168.56.10${i+1}"
      port = 22
      type = i <= 1 ? "server" : "agent"
    }
  ])
}

module "k3s" {
  source      = "./k3s"
  private_key_path = "./vagrant_key"
  user        = "vagrant"
  nodes = local.nodes
}
