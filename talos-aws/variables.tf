variable "name" {
  description = "Project name, required to create unique resource names"
  type = "string"
  default = "talos-learning"
}

variable "region" {
    description = "The region name"
    type = "string"
    default = "eu-north-1"
}

variable "network_shift" {
    description = "Network number shift"
    type = number
    default = 2
}

variable "tags" {
    description = "Tags of resources"
    type = map(string)
    default = {
      Name = "talos"
      Environment = "Develop"
    }
}