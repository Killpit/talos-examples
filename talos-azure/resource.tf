resource "azurerm_resource_group" "this" {
  name     = var.cluster_name
  location = var.azure_location
  tags     = var.extra_tags
}

resource "azurerm_network_interface_backend_address_pool_association" "this" {
  count = var.control_plane.num_instances

  ip_configuration_name   = "${var.cluster_name}-control-plane-ip-${count.index}"
  backend_address_pool_id = module.kubernetes_api_lb.azurerm_lb_backend_address_pool_id
  network_interface_id    = module.talos_control_plane_nodes.network_interface_ids[count.index]
}

resource "talos_machine_secrets" "this" {}

resource "talos_machine_configuration_apply" "controlplane" {
  count = var.control_plane.num_instances

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  endpoint                    = module.talos_control_plane_nodes.public_ip_address[count.index]
  node                        = module.talos_control_plane_nodes.network_interface_private_ip[count.index]
}

resource "talos_machine_configuration_apply" "worker_group" {
  for_each = merge([
    for info in var.worker_groups : {
      for index in range(0, info.num_instances) :
      "${info.name}.${index}" => {
        name       = info.name,
        public_ip  = module.talos_worker_group[info.name].public_ip_address[index],
        private_ip = module.talos_worker_group[info.name].network_interface_private_ip[index]
      }
    }
  ]...)

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker_group[each.value.name].machine_configuration
  endpoint                    = each.value.public_ip
  node                        = each.value.private_ip
}

resource "talos_machine_bootstrap" "this" {
  depends_on = [talos_machine_configuration_apply.controlplane]

  client_configuration = talos_machine_secrets.this.client_configuration
  endpoint             = module.talos_control_plane_nodes.public_ip_address[0]
  node                 = module.talos_control_plane_nodes.network_interface_private_ip[0]
}

resource "talos_cluster_kubeconfig" "this" {
  depends_on = [talos_machine_bootstrap.this]

  client_configuration = talos_machine_secrets.this.client_configuration
  endpoint             = module.talos_control_plane_nodes.public_ip_address[0]
  node                 = module.talos_control_plane_nodes.network_interface_private_ip[0]
}