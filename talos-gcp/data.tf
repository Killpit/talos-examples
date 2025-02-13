data "google_compute_zones" "available" {}

data "google_netblock_ip_ranges" "this" {
  range_type = "health-checkers"
}

data "talos_machine_configuration" "controlplane" {
  cluster_name       = var.cluster_name
  cluster_endpoint   = "https://${google_compute_global_forwarding_rule.this.ip_address}"
  machine_type       = "controlplane"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  talos_version      = var.talos_version_contract
  kubernetes_version = var.kubernetes_version
  docs               = false
  examples           = false
  config_patches = concat(
    [for path in var.control_plane.config_patch_files : file(path)]
  )
}

data "talos_machine_configuration" "worker_group" {
  for_each = merge([for info in var.worker_groups : { "${info.name}" = info }]...)

  cluster_name       = var.cluster_name
  cluster_endpoint   = "https://${google_compute_global_forwarding_rule.this.ip_address}"
  machine_type       = "worker"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  talos_version      = var.talos_version_contract
  kubernetes_version = var.kubernetes_version
  docs               = false
  examples           = false
  config_patches = concat(
    [for path in each.value.config_patch_files : file(path)]
  )
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [for interface in google_compute_instance.cp.*.network_interface : interface[0].access_config[0].nat_ip]
  nodes = concat(
    [for interface in google_compute_instance.cp.*.network_interface : interface[0].access_config[0].nat_ip],
    [for instance in google_compute_instance.workers : instance.network_interface[0].network_ip],
  )
}

data "talos_cluster_health" "this" {
  depends_on = [
    talos_machine_configuration_apply.controlplane,
    talos_machine_configuration_apply.worker_group,
    talos_cluster_kubeconfig.this
  ]

  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [for interface in google_compute_instance.cp.*.network_interface : interface[0].access_config[0].nat_ip]
  control_plane_nodes  = [for interface in google_compute_instance.cp.*.network_interface : interface[0].network_ip]
  worker_nodes         = [for instance in google_compute_instance.workers : instance.network_interface[0].network_ip]
}