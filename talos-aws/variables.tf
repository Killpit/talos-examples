variable "cluster_name" {
  default = "aws-talos-example"
  description = "The name of the cluster"
  type = string
}

variable "cluster_architecture" {
  description = "Cluster architecture. Choose 'arm64' or 'amd64'. If you choose 'arm64', ensure to also override the control_plane.instance_type"
  type        = string
  default     = "amd64"
}

variable "control_plane" {
  description = "Info for control plane that will be created"
  type = object({
    instance_type        = optional(string, "m5.large")
    config_patch_files   = optional(list(string), [])
    tags                 = optional(map(string), {})
  })
  default = {}
}

variable "worker_groups" {
  description = "List of worker node groups to create"
  type = list(object({
    name                = string
    instance_type       = optional(string, "m5.large")
    config_patch_files  = optional(list(string), [])
    tags                = optional(map(string), {})
  }))
  default = []
}

variable "region" {
  description = "The AWS region where the cluster will be deployed"
  type        = string
}

variable "owner" {
  description = "Owner for resource tagging"
  type        = string
}

variable "vpc_cidr" {
  description = "The CIDR to use for the VPC. Must be a /16 or /24."
  type        = string
  default     = "10.0.0.0/16"
}

variable "service_cidr" {
  description = "The CIDR range for Kubernetes Services"
  type        = string
  default     = "100.68.0.0/16"
}

variable "pod_cidr" {
  description = "The CIDR range for Kubernetes Pods"
  type        = string
  default     = "100.64.0.0/14"
}

variable "allocate_node_cidrs" {
  description = "Assign PodCIDRs to Node resources (Only needed if using Cilium Kubernetes IPAM mode)"
  type        = bool
  default     = false
}

# Kubernetes & Talos Configuration
variable "talos_version" {
  description = "Talos version to use for the cluster. Check https://github.com/siderolabs/talos/releases"
  type        = string
  default     = "v1.9.2"
}

variable "kubernetes_version" {
  description = "Kubernetes version to use for the Talos cluster. Check https://www.talos.dev/latest/introduction/support"
  type        = string
  default     = "v1.32.0"
}

variable "disable_kube_proxy" {
  description = "Determines whether Kube-Proxy should be deployed (set to true if using an alternative CNI like Cilium)"
  type        = bool
  default     = false
}

# Consolidated Resource Tags
variable "tags" {
  description = "The set of tags to place on the created resources."
  type        = map(string)
  default = {
    usage       = "aws-example"
    platform    = "talos"
    Name        = "talos"
    Environment = "Develop"
  }
}

variable "region" {
  description = "The AWS region to deploy resources"
  type        = string
}