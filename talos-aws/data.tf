data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "talos" {
  owners = ["540036508848"] # Sidero Labs
  most_recent = true
  name_regex = "^talos-v\\d+\\.\\d+\\.\\d+-${data.aws_availability_zones.available.id}-amd64$"
}

data "talos_machine_configuration" "controlplane" {
  cluster_name = var.cluster_name
  cluster_endpoint = "https://${module.elb_k8s_elb.elb_dns_name}"
  machine_type = "controlplane"
  machine_secrets = talos_machine_secrets.this.machine_secrets
  talos_version = var.talos_version_contract
  kubernetes_version = var.kubernetes_version
  docs = false
  examples = false
  config_patches = concat(
    local.config_patches_common,
    local.config_patches_controlplane,
    [yamlencode(local.common_machine_config_patch)],
    [for path in var.control_plane.config_patch_files : file(path)]
  )
}

data "talos_machine_configuration" "worker_group" {
  cluster_name = var.cluster_name
  cluster_endpoint = "https://${module.elb_k8s_elb.elb_dns_name}"
  machine_type = "worker"
  machine_secrets = talos_machine_secrets.this.machine_secrets
  talos_version = var.talos_version_contract
  kubernetes_version = var.kubernetes_version
  docs = false
  examples = false
  config_patches = concat(
    local.config_patches_common,
    local.config_patches_worker,
    [yamlencode(local.common_machine_config_patch)],
    [for path in each.value.config_patch_files : file(path)]
  )
}

data "talos_client_configuration" "this" {
  cluster_name = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints = module.talos_control_plane_nodes.*.public_ip
  nodes = flatten([module.talos_control_plane_nodes.*.public_ip, flatten([for node in module.talos_worker_group : node.private_ip])])
}

data "talos_cluster_health" "this" {
  depends_on = [
    talos_machine_configuration_apply.controlplane,
    talos_machine_configuration_apply.worker_group,
    talos_cluster_kubeconfig.this
  ]

  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = module.talos_control_plane_nodes.*.public_ip
  control_plane_nodes  = module.talos_control_plane_nodes.*.private_ip
  worker_nodes         = [for node in module.talos_worker_group : node.private_ip]
}