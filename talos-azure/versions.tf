terraform {
    required_version = "~> 1.10"
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "4.18.0"
    }
    talos = {
      source = "siderolabs/talos"
      version = "0.7.0"
    }
  }
}

provider "azurerm" {
  features {}
}