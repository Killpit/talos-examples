resource "google_compute_instance_group" "talos-cp-ig" {
  name        = "${var.cluster_name}-cp-ig"
  description = "Talos Control Plane Instance Group"
  zone        = var.zone
  network     = module.vpc.network_self_link
  named_port {
    name = "tcp6443"
    port = 6443
  }
}

resource "google_compute_health_check" "this" {
  name = "${var.cluster_name}-cp-hc"
  tcp_health_check {
    port = 6443
  }
}

resource "google_compute_backend_service" "this" {
  name = "${var.cluster_name}-cp-bs"
  backend {
    group = google_compute_instance_group.talos-cp-ig.id
  }
  health_checks = [google_compute_health_check.this.id]
  port_name     = "tcp6443"
  protocol      = "TCP"
  timeout_sec   = 300
}

resource "google_compute_target_tcp_proxy" "this" {
  name            = "${var.cluster_name}-cp-tcp-proxy"
  backend_service = google_compute_backend_service.this.id
  proxy_header    = "NONE"
}

resource "google_compute_global_address" "this" {
  name = "${var.cluster_name}-cp-address"
}

resource "google_compute_global_forwarding_rule" "this" {
  name        = "${var.cluster_name}-cp-forwarding-rule"
  target      = google_compute_target_tcp_proxy.this.id
  port_range  = "443"
  ip_protocol = "TCP"
  ip_address  = google_compute_global_address.this.id
}

resource "google_compute_firewall" "health-check" {
  name    = "${var.cluster_name}-cp-health-check"
  network = module.vpc.network_name
  allow {
    protocol = "tcp"
    ports    = ["6443"]
  }
  source_ranges = data.google_netblock_ip_ranges.this.cidr_blocks_ipv4
  target_tags   = ["talos-api"]
}

resource "google_compute_firewall" "talos-api" {
  name    = "${var.cluster_name}-talos-api"
  network = module.vpc.network_name
  allow {
    protocol = "tcp"
    ports    = ["50000"]
  }
  source_ranges = [var.talos_api_allowed_cidr]
  target_tags   = ["talos-api"]
}

resource "google_compute_instance" "cp" {
  count        = var.control_plane.num_instances
  name         = "${var.cluster_name}-cp-${count.index}"
  machine_type = var.control_plane.instance_type
  tags         = ["talos-api"]
  boot_disk {
    initialize_params {
      image = var.control_plane.image
    }
  }
  network_interface {
    subnetwork = module.vpc.subnets[keys(module.vpc.subnets)[0]].self_link
    access_config {
      network_tier = "PREMIUM"
    }
  }
}

resource "google_compute_instance" "workers" {
  for_each = merge([for info in var.worker_groups : { for index in range(0, info.num_instances) : "${info.name}.${index}" => info }]...)

  name         = "${var.cluster_name}-worker-group-${each.value.name}-${trimprefix(each.key, "${each.value.name}.")}"
  machine_type = each.value.instance_type
  tags         = ["talos-api"]
  boot_disk {
    initialize_params {
      image = each.value.image == null ? var.control_plane.image : each.value.image
    }
  }
  network_interface {
    subnetwork = module.vpc.subnets[keys(module.vpc.subnets)[0]].self_link
    access_config {
      network_tier = "PREMIUM"
    }
  }
}

resource "google_compute_instance_group_membership" "this" {
  count          = var.control_plane.num_instances
  instance       = google_compute_instance.cp[count.index].self_link
  instance_group = google_compute_instance_group.talos-cp-ig.self_link
}

resource "talos_machine_secrets" "this" {}

resource "talos_machine_configuration_apply" "controlplane" {
  depends_on = [
    google_compute_firewall.health-check,
    google_compute_firewall.talos-api,
  ]

  count = var.control_plane.num_instances

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  endpoint                    = google_compute_instance.cp[count.index].network_interface[0].access_config[0].nat_ip
  node                        = google_compute_instance.cp[count.index].network_interface[0].access_config[0].nat_ip
}

resource "talos_machine_configuration_apply" "worker_group" {
  depends_on = [
    google_compute_firewall.health-check,
    google_compute_firewall.talos-api,
  ]

  for_each = merge([
    for info in var.worker_groups : {
      for index in range(0, info.num_instances) :
      "${info.name}.${index}" => {
        name       = info.name,
        public_ip  = google_compute_instance.workers["${info.name}.${index}"].network_interface[0].access_config[0].nat_ip,
        private_ip = google_compute_instance.workers["${info.name}.${index}"].network_interface[0].network_ip
      }
    }
  ]...)

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker_group[each.value.name].machine_configuration
  endpoint                    = each.value.public_ip
  node                        = each.value.public_ip
}

resource "talos_machine_bootstrap" "this" {
  depends_on = [talos_machine_configuration_apply.controlplane]

  client_configuration = talos_machine_secrets.this.client_configuration
  endpoint             = google_compute_instance.cp[0].network_interface[0].access_config[0].nat_ip
  node                 = google_compute_instance.cp[0].network_interface[0].access_config[0].nat_ip
}

resource "talos_cluster_kubeconfig" "this" {
  depends_on = [talos_machine_bootstrap.this]

  client_configuration = talos_machine_secrets.this.client_configuration
  endpoint             = google_compute_instance.cp[0].network_interface[0].access_config[0].nat_ip
  node                 = google_compute_instance.cp[0].network_interface[0].access_config[0].nat_ip
}
