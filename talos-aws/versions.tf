terraform {
  required_version = "~> 1.10"
  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "~> 5.0"
    }
    talos = {
        source = "siderolabs/talos"
        version = "0.7.0"
    }
  }
}

provider "aws" {
  default_tags {
    tags = {
        Project = "Talos Kubernetes Cluster"
        Provisioner = "Terraform"
        Environment = "Testing"
    }
  }
}