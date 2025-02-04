module "talos" {
  source = "git::https://github.com/isovalent/terraform-aws-talos.git?ref=v1.10"

  talos_version = var.talos_version
  kubernetes_version = var.kubernetes_version
  cluster_name = var.cluster_name
  cluster_architecture = var.cluster_architecture
  control_plane = var.control_plane
  worker_groups = var.worker_groups
  region = var.region
  allocate_node_cidrs = var.allocate_node_cidrs
  disable_kube_proxy = var.disable_kube_proxy
  controlplane_count = 3
  workers_count = 5
  vpc_id = module.vpc_id
  pod_cidr = var.pod_cidr
  service_cidr = var.service_cidr
}