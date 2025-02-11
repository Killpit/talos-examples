terraform {
    required_version = "~> 1.10"
    required_providers {
    google = {
      source = "hashicorp/google"
      version = "6.20.0"
    }
    talos = {
        source = "siderolabs/talos"
        version = "0.7.0"
    }
  }
}

provider "google" {
  project = var.project
  region = var.region
  zone = var.zone
}