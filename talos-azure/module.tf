module "vnet" {
  source     = "Azure/network/azurerm"
  version    = "~> 5.0"
  depends_on = [azurerm_resource_group.this]

  vnet_name    = var.cluster_name
  use_for_each = true

  resource_group_name = azurerm_resource_group.this.name
  address_space       = var.vnet_cidr
  subnet_prefixes     = cidrsubnets(var.vnet_cidr, 2)

  tags = var.extra_tags
}

module "control_plane_sg" {
  source     = "Azure/network-security-group/azurerm"
  version    = "~> 3.0"
  depends_on = [azurerm_resource_group.this]

  security_group_name   = var.cluster_name
  resource_group_name   = azurerm_resource_group.this.name
  source_address_prefix = [var.talos_api_allowed_cidr]

  custom_rules = [
    {
      name                   = "talos_api"
      priority               = "101"
      direction              = "Inbound"
      access                 = "Allow"
      protocol               = "Tcp"
      source_address_prefix  = var.talos_api_allowed_cidr
      destination_port_range = "50000"
    },
    {
      name                   = "kubernetes_api"
      priority               = "102"
      direction              = "Inbound"
      access                 = "Allow"
      protocol               = "Tcp"
      source_address_prefix  = var.kubernetes_api_allowed_cidr
      destination_port_range = "6443"
    },
  ]

  tags = var.extra_tags
}

module "kubernetes_api_lb" {
  source     = "Azure/loadbalancer/azurerm"
  version    = "~> 4.0"
  depends_on = [azurerm_resource_group.this]

  prefix              = var.cluster_name
  resource_group_name = azurerm_resource_group.this.name
  type                = "public"
  lb_sku              = "Standard"
  pip_sku             = "Standard"

  lb_port = {
    k8sapi = ["443", "Tcp", "6443"]
  }

  lb_probe = {
    k8sapi = ["Tcp", "6443", ""]
  }

  tags = var.extra_tags
}
module "talos_control_plane_nodes" {
  source     = "Azure/compute/azurerm"
  version    = "~> 5.0"
  depends_on = [azurerm_resource_group.this]

  resource_group_name           = azurerm_resource_group.this.name
  vm_hostname                   = "${var.cluster_name}-control-plane"
  enable_ssh_key                = false
  admin_password                = "mAk1ngp6ov1derH00py" // just to make the provider happy, talos doesn't use it
  nb_instances                  = var.control_plane.num_instances
  nb_public_ip                  = var.control_plane.num_instances
  public_ip_sku                 = "Standard"
  allocation_method             = "Static"
  vm_size                       = var.control_plane.vm_size
  vm_os_id                      = var.control_plane.vm_os_id
  delete_os_disk_on_termination = true
  storage_os_disk_size_gb       = 100
  vnet_subnet_id                = module.vnet.vnet_subnets[0]
  network_security_group        = { id = module.control_plane_sg.network_security_group_id }
  source_address_prefixes       = [var.talos_api_allowed_cidr]

  as_platform_fault_domain_count  = 3
  as_platform_update_domain_count = 5

  tags = var.extra_tags
}

module "talos_worker_group" {
  source     = "Azure/compute/azurerm"
  version    = "~> 5.0"
  depends_on = [azurerm_resource_group.this]

  for_each = merge([for info in var.worker_groups : { "${info.name}" = info }]...)

  resource_group_name           = azurerm_resource_group.this.name
  vm_hostname                   = "${var.cluster_name}-worker-group-${each.key}"
  enable_ssh_key                = false
  admin_password                = "mAk1ngp6ov1derH00py" // just to make the provider happy, talos doesn't use it
  nb_instances                  = each.value.num_instances
  nb_public_ip                  = each.value.num_instances
  vm_size                       = each.value.vm_size
  vm_os_id                      = each.value.vm_os_id
  delete_os_disk_on_termination = true
  storage_os_disk_size_gb       = 100
  vnet_subnet_id                = module.vnet.vnet_subnets[0]
  remote_port                   = "50000"
  source_address_prefixes       = [var.talos_api_allowed_cidr]

  as_platform_fault_domain_count  = 3
  as_platform_update_domain_count = 5

  tags = var.extra_tags
}

