data "talos_machine_configuration" "controlplane" {
  cluster_name       = var.cluster_name
  cluster_endpoint   = "https://${module.kubernetes_api_lb.azurerm_public_ip_address[0]}"
  machine_type       = "controlplane"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  talos_version      = var.talos_version_contract
  kubernetes_version = var.kubernetes_version
  docs               = false
  examples           = false
  config_patches = concat(
    local.config_patches_common,
    [for path in var.control_plane.config_patch_files : file(path)]
  )
}

data "talos_machine_configuration" "worker_group" {
  for_each = merge([for info in var.worker_groups : { "${info.name}" = info }]...)

  cluster_name       = var.cluster_name
  cluster_endpoint   = "https://${module.kubernetes_api_lb.azurerm_public_ip_address[0]}"
  machine_type       = "worker"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  talos_version      = var.talos_version_contract
  kubernetes_version = var.kubernetes_version
  docs               = false
  examples           = false
  config_patches = concat(
    local.config_patches_common,
    [for path in each.value.config_patch_files : file(path)]
  )
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = module.talos_control_plane_nodes.public_ip_address
  nodes                = flatten([module.talos_control_plane_nodes.network_interface_private_ip, flatten([for node in module.talos_worker_group : node.network_interface_private_ip])])
}

data "talos_cluster_health" "this" {
  depends_on = [
    talos_machine_configuration_apply.controlplane,
    talos_machine_configuration_apply.worker_group,
    talos_cluster_kubeconfig.this
  ]

  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = flatten(module.talos_control_plane_nodes.*.public_ip_address)
  control_plane_nodes  = flatten(module.talos_control_plane_nodes.*.network_interface_private_ip)
  worker_nodes         = flatten([for node in module.talos_worker_group : node.network_interface_private_ip])
}