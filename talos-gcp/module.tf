module "vpc" {
  source  = "terraform-google-modules/network/google"
  version = "~> 9.1"

  project_id   = var.project
  network_name = var.cluster_name

  subnets = [
    {
      subnet_name   = "main"
      subnet_ip     = var.vpc_cidr
      subnet_region = var.region
    }
  ]

  egress_rules = [
    {
      name        = "allow-egress"
      description = "Allow all egress traffic"
      priority    = 999
      allow = [
        {
          protocol = "all"
        }
      ]
      destination_ranges = ["0.0.0.0/0"]
    }
  ]

  ingress_rules = [
    {
      name        = "allow-internal"
      description = "Allow all internal traffic"
      priority    = 65534
      allow = [
        {
          protocol = "all"
        }
      ]
      source_ranges = [var.vpc_cidr]
    },
    {
      name        = "allow-icmp"
      description = "Allow ICMP from anywhere"
      priority    = 65534
      allow = [
        {
          protocol = "icmp"
        }
      ]
      source_ranges = ["0.0.0.0/0"]
    }
  ]
}
