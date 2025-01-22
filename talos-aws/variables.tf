variable "name" {
  description = "Project name, required to create unique resource names"
  type = "string"
  default = "talos-aws-example"
}

variable "cluster_architecture" {
  default = "amd64"
  description = "Cluster architecture. Choose 'arm64' or 'amd64'. If you choose 'arm64', ensure to also override the control_plane.instance_type"
  type = string
}

variable "control_plane" {
  default = {}
  description = "Info for control plane that will be created"
  type = object({
    instance_type = optional(string, "m5.large")
    config_patch_files = optional(list(string), [])
    tags = optional(map(string), {})
  })
}

variable "worker_groups" {
  default = [{
    name = "default"
  }]
  description = "List of node worker node groups to create"
  type = list(object({
    name = string
    instance_type = optional(string, "m5.large")
    config_patch_files = optional(list(string), [])
    tags = optional(map(string), {})
  }))
}

variable "region" {
    description = "The region name"
    type = "string"
}

variable "owner" {
  description = "Owner for resource tagging"
  type = string
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
  description = "The CIDR to use for the VPC. Currently it must be a /16 or /24"
  type = string
}

variable "tags" {
  default = {
    usage = "aws-example",
    platform = "talos"
  }
  description = "The set of tags to place on the created resources. These will be merged with the default tags defined via local.tags in 00-locals.tf"
  type = map(string)
}

# talos module
variable "talos_version" {
  default = "v1.9.2"
  description = "Talos version to use for the cluster, if not set the newest Talos version. Check https://github.com/siderolabs/talos/releases for available releases"
  type = string
}

variable "kubernetes_version" {
  default = "v1.32.0"
  description = "Kubernetes version to use for the Talos cluster, if not set, the K8s version shipped with the selected Talos version will be used. Check https://www.talos.dev/latest/introduction/support"
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