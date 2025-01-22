terraform {
  required_providers {
    talos = {
      source = "siderolabs/talos"
      version = "0.7.0"
    }

    aws = {
      source = "hashicorp/aws"
      version = "5.84.0"
      region = var.region
    }
  }
}
