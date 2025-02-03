resource "random_id" "cluster" {
  byte_length = 4
}

module "vpc" {
  source = "git::https://github.com/isovalent/terraform-aws-vpc.git?ref=v1.10"

  cidr = var.vpc_cidr
  name = "${var.cluster_name}-${random_id.cluster.dec}"
}