module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"

  name = var.cluster_name
  cidr = var.vpc_cidr
  tags = var.extra_tags

  # lets pick utmost three AZ's since the CIDR bit is 2
  azs            = slice(data.aws_availability_zones.available.names, 0, 3)
  public_subnets = [for i, v in slice(data.aws_availability_zones.available.names, 0, 3) : cidrsubnet(var.vpc_cidr, 2, i)]
}

module "cluster_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = var.cluster_name
  description = "Allow all intra-cluster and egress traffic"
  vpc_id      = module.vpc.vpc_id
  tags        = var.extra_tags

  ingress_with_self = [
    {
      rule = "all-all"
    },
  ]

  ingress_with_cidr_blocks = [
    {
      from_port   = 50000
      to_port     = 50000
      protocol    = "tcp"
      cidr_blocks = var.talos_api_allowed_cidr
      description = "Talos API Access"
    },
  ]

  egress_with_cidr_blocks = [
    {
      rule        = "all-all"
      cidr_blocks = "0.0.0.0/0"
    },
  ]
}

module "kubernetes_api_sg" {
  source  = "terraform-aws-modules/security-group/aws//modules/https-443"
  version = "~> 4.0"

  name                = "${var.cluster_name}-k8s-api"
  description         = "Allow access to the Kubernetes API"
  vpc_id              = module.vpc.vpc_id
  ingress_cidr_blocks = [var.kubernetes_api_allowed_cidr]
  tags                = var.extra_tags
}

module "elb_k8s_elb" {
  source  = "terraform-aws-modules/elb/aws"
  version = "~> 4.0"

  name    = substr("${var.cluster_name}-k8s-api", 0, 32)
  subnets = module.vpc.public_subnets
  tags    = merge(var.extra_tags, local.cluster_required_tags)
  security_groups = [
    module.cluster_sg.security_group_id,
    module.kubernetes_api_sg.security_group_id,
  ]

  listener = [
    {
      lb_port           = 443
      lb_protocol       = "tcp"
      instance_port     = 6443
      instance_protocol = "tcp"
    },
  ]

  health_check = {
    target              = "tcp:6443"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
  }

  number_of_instances = var.control_plane.num_instances
  instances           = module.talos_control_plane_nodes.*.id
}

module "talos_control_plane_nodes" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 4.0"

  count = var.control_plane.num_instances

  name                        = "${var.cluster_name}-control-plane-${count.index}"
  ami                         = var.control_plane.ami_id == null ? data.aws_ami.talos.id : var.control_plane.ami_id
  monitoring                  = true
  instance_type               = var.control_plane.instance_type
  subnet_id                   = element(module.vpc.public_subnets, count.index)
  iam_role_use_name_prefix    = false
  create_iam_instance_profile = var.ccm ? true : false
  iam_role_policies = var.ccm ? {
    "${var.cluster_name}-control-plane-ccm-policy" : aws_iam_policy.control_plane_ccm_policy[0].arn,
  } : {}
  tags = merge(var.extra_tags, var.control_plane.tags, local.cluster_required_tags)

  vpc_security_group_ids = [module.cluster_sg.security_group_id]

  root_block_device = [
    {
      volume_size = 100
    }
  ]
}

module "talos_worker_group" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 4.0"

  for_each = merge([for info in var.worker_groups : { for index in range(0, info.num_instances) : "${info.name}.${index}" => info }]...)

  name                        = "${var.cluster_name}-worker-group-${each.value.name}-${trimprefix(each.key, "${each.value.name}.")}"
  ami                         = each.value.ami_id == null ? data.aws_ami.talos.id : each.value.ami_id
  monitoring                  = true
  instance_type               = each.value.instance_type
  subnet_id                   = element(module.vpc.public_subnets, tonumber(trimprefix(each.key, "${each.value.name}.")))
  iam_role_use_name_prefix    = false
  create_iam_instance_profile = var.ccm ? true : false
  iam_role_policies = var.ccm ? {
    "${var.cluster_name}-worker-ccm-policy" : aws_iam_policy.worker_ccm_policy[0].arn,
  } : {}
  tags = merge(each.value.tags, var.extra_tags, local.cluster_required_tags)

  vpc_security_group_ids = [module.cluster_sg.security_group_id]

  root_block_device = [
    {
      volume_size = 100
    }
  ]
}