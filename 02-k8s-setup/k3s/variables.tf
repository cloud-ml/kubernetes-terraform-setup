variable "nodes" {
  type = list(object({
    name      = string
    host      = string
    port      = number
    type      = string
  }))
}

variable "private_key_path" {
    type = string
}

variable "user" {
    type = string  
}

variable "additional_k3s_args" {
    type = string
}

